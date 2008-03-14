// Written by Christopher E. Miller
// See the included license.txt for copyright and license details.


///
module dfl.listview;

private import dfl.internal.dlib, dfl.internal.clib;

private import dfl.base, dfl.control, dfl.internal.winapi, dfl.application;
private import dfl.event, dfl.drawing, dfl.collections, dfl.internal.utf;

version(DFL_NO_IMAGELIST)
{
}
else
{
	private import dfl.imagelist;
}


private extern(Windows) void _initListview();


///
enum ListViewAlignment: ubyte
{
	TOP, ///
	DEFAULT, /// ditto
	LEFT, /// ditto
	SNAP_TO_GRID, /// ditto
}


private union CallText
{
	char* ansi;
	wchar* unicode;
}


private CallText getCallText(char[] text)
{
	CallText result;
	if(text is null)
	{
		if(useUnicode)
			result.unicode = null;
		else
			result.ansi = null;
	}
	else
	{
		if(useUnicode)
			result.unicode = toUnicodez(text);
		else
			result.ansi = toAnsiz(text);
	}
	return result;
}


package union LvColumn
{
	LV_COLUMNW lvcw;
	LV_COLUMNA lvca;
	struct
	{
		UINT mask;
		int fmt;
		int cx;
		private void* pszText;
		int cchTextMax;
		int iSubItem;
	}
}


///
class ListViewSubItem: DObject
{
	///
	this()
	{
		Application.ppin(cast(void*)this);
	}
	
	/// ditto
	this(char[] thisSubItemText)
	{
		this();
		
		settextin(thisSubItemText);
	}
	
	/// ditto
	this(ListViewItem owner, char[] thisSubItemText)
	{
		this();
		
		settextin(thisSubItemText);
		if(owner)
		{
			this._item = owner;
			owner.subItems.add(this);
		}
	}
	
	/+
	this(Object obj) // package
	{
		this(getObjectString(obj));
	}
	+/
	
	
	package final void settextin(char[] newText)
	{
		calltxt = getCallText(newText);
		_txt = newText;
	}
	
	
	override char[] toString()
	{
		return text;
	}
	
	
	override int opEquals(Object o)
	{
		return text == getObjectString(o);
	}
	
	
	int opEquals(char[] val)
	{
		return text == val;
	}
	
	
	override int opCmp(Object o)
	{
		return stringICmp(text, getObjectString(o));
	}
	
	
	int opCmp(char[] val)
	{
		return stringICmp(text, val);
	}
	
	
	///
	final void text(char[] newText) // setter
	{
		settextin(newText);
		
		if(_item && _item.lview && _item.lview.created)
		{
			int ii, subi;
			ii = _item.lview.items.indexOf(_item);
			assert(-1 != ii);
			subi = _item.subItems.indexOf(this);
			assert(-1 != subi);
			_item.lview.updateItemText(ii, newText, subi + 1); // Sub items really start at 1 in the list view.
		}
	}
	
	/// ditto
	final char[] text() // getter
	{
		return _txt;
	}
	
	
	private:
	package ListViewItem _item;
	char[] _txt;
	package CallText calltxt;
}


///
class ListViewItem: DObject
{
	///
	static class ListViewSubItemCollection
	{
		protected this(ListViewItem owner)
		in
		{
			assert(!owner.isubs);
		}
		body
		{
			_item = owner;
		}
		
		
		private:
		
		ListViewItem _item;
		package ListViewSubItem[] _subs;
		
		
		void _added(size_t idx, ListViewSubItem val)
		{
			if(val._item)
				throw new DflException("ListViewSubItem already belongs to a ListViewItem");
		}
		
		
		public:
		
		mixin ListWrapArray!(ListViewSubItem, _subs,
			_blankListCallback!(ListViewSubItem), _added,
			_blankListCallback!(ListViewSubItem), _blankListCallback!(ListViewSubItem),
			true, false, false);
	}
	
	
	///
	this()
	{
		Application.ppin(cast(void*)this);
		
		isubs = new ListViewSubItemCollection(this);
	}
	
	/// ditto
	this(char[] text)
	{
		this();
		
		settextin(text);
	}
	
	
	private final void _setcheckstate(int thisindex, bool bchecked)
	{
		if(lview && lview.created)
		{
			LV_ITEMA li;
			li.stateMask = LVIS_STATEIMAGEMASK;
			li.state = cast(LPARAM)(bchecked ? 2 : 1) << 12;
			lview.prevwproc(LVM_SETITEMSTATE, cast(WPARAM)thisindex, cast(LPARAM)&li);
		}
	}
	
	
	private final bool _getcheckstate(int thisindex)
	{
		if(lview && lview.created)
		{
			if((lview.prevwproc(LVM_GETITEMSTATE, cast(WPARAM)thisindex, LVIS_STATEIMAGEMASK) >> 12) - 1)
				return true;
		}
		return false;
	}
	
	
	///
	final void checked(bool byes) // setter
	{
		return _setcheckstate(index, byes);
	}
	
	/// ditto
	final bool checked() // getter
	{
		return _getcheckstate(index);
	}
	
	
	package final void settextin(char[] newText)
	{
		calltxt = getCallText(newText);
		_txt = newText;
	}
	
	
	override char[] toString()
	{
		return text;
	}
	
	
	override int opEquals(Object o)
	{
		return text == getObjectString(o);
	}
	
	
	int opEquals(char[] val)
	{
		return text == val;
	}
	
	
	override int opCmp(Object o)
	{
		return stringICmp(text, getObjectString(o));
	}
	
	
	int opCmp(char[] val)
	{
		return stringICmp(text, val);
	}
	
	
	///
	final Rect bounds() // getter
	{
		if(lview)
		{
			int i = index;
			assert(-1 != i);
			return lview.getItemRect(i);
		}
		return Rect(0, 0, 0, 0);
	}
	
	
	///
	final int index() // getter
	{
		if(lview)
			return lview.litems.indexOf(this);
		return -1;
	}
	
	
	///
	final void text(char[] newText) // setter
	{
		settextin(newText);
		
		if(lview && lview.created)
			lview.updateItemText(this, newText);
	}
	
	/// ditto
	final char[] text() // getter
	{
		return _txt;
	}
	
	
	///
	final void selected(bool byes) // setter
	{
		if(lview && lview.created)
		{
			LV_ITEMA li;
			li.stateMask = LVIS_SELECTED;
			if(byes)
				li.state = LVIS_SELECTED;
			lview.prevwproc(LVM_SETITEMSTATE, cast(WPARAM)index, cast(LPARAM)&li);
		}
	}
	
	/// ditto
	final bool selected() // getter
	{
		if(lview && lview.created)
		{
			if(lview.prevwproc(LVM_GETITEMSTATE, cast(WPARAM)index, LVIS_SELECTED))
				return true;
		}
		return false;
	}
	
	
	///
	final ListView listView() // getter
	{
		return lview;
	}
	
	
	///
	final void tag(Object obj) // setter
	{
		_tag = obj;
	}
	
	/// ditto
	final Object tag() // getter
	{
		return _tag;
	}
	
	
	///
	final ListViewSubItemCollection subItems() // getter
	{
		return isubs;
	}
	
	
	version(DFL_NO_IMAGELIST)
	{
	}
	else
	{
		///
		final void imageIndex(int index) // setter
		{
			this._imgidx = index;
			
			if(lview && lview.created)
				lview.updateItem(this);
		}
		
		/// ditto
		final int imageIndex() // getter
		{
			return _imgidx;
		}
	}
	
	
	private:
	package ListView lview = null;
	Object _tag = null;
	package ListViewSubItemCollection isubs = null;
	version(DFL_NO_IMAGELIST)
	{
	}
	else
	{
		int _imgidx = -1;
	}
	char[] _txt;
	package CallText calltxt;
}


///
class ColumnHeader: DObject
{
	///
	this(char[] text)
	{
		this();
		
		this._txt = text;
	}
	
	/// ditto
	this()
	{
		Application.ppin(cast(void*)this);
	}
	
	
	///
	final ListView listView() // getter
	{
		return lview;
	}
	
	
	///
	final void text(char[] newText) // setter
	{
		_txt = newText;
		
		if(lview && lview.created)
		{
			lview.updateColumnText(this, newText);
		}
	}
	
	/// ditto
	final char[] text() // getter
	{
		return _txt;
	}
	
	
	override char[] toString()
	{
		return text;
	}
	
	
	override int opEquals(Object o)
	{
		return text == getObjectString(o);
	}
	
	
	int opEquals(char[] val)
	{
		return text == val;
	}
	
	
	override int opCmp(Object o)
	{
		return stringICmp(text, getObjectString(o));
	}
	
	
	int opCmp(char[] val)
	{
		return stringICmp(text, val);
	}
	
	
	///
	final int index() // getter
	{
		if(lview)
			lview.cols.indexOf(this);
		return -1;
	}
	
	
	///
	final void textAlign(HorizontalAlignment halign) // setter
	{
		_align = halign;
		
		if(lview && lview.created)
		{
			lview.updateColumnAlign(this, halign);
		}
	}
	
	/// ditto
	final HorizontalAlignment textAlign() // getter
	{
		return _align;
	}
	
	
	///
	final void width(int w) // setter
	{
		_width = w;
		
		if(lview && lview.created)
		{
			lview.updateColumnWidth(this, w);
		}
	}
	
	/// ditto
	final int width() // getter
	{
		if(lview && lview.created)
		{
			int xx;
			xx = lview.getColumnWidth(this);
			if(-1 != xx)
				_width = xx;
		}
		return _width;
	}
	
	
	private:
	package ListView lview;
	char[] _txt;
	int _width;
	HorizontalAlignment _align;
}


///
class LabelEditEventArgs: EventArgs
{
	///
	this(ListViewItem item, char[] label)
	{
		_item = item;
		_label = label;
	}
	
	/// ditto
	this(ListViewItem node)
	{
		_item = item;
	}
	
	
	///
	final ListViewItem item() // getter
	{
		return _item;
	}
	
	
	///
	final char[] label() // getter
	{
		return _label;
	}
	
	
	///
	final void cancelEdit(bool byes) // setter
	{
		_cancel = byes;
	}
	
	/// ditto
	final bool cancelEdit() // getter
	{
		return _cancel;
	}
	
	
	private:
	ListViewItem _item;
	char[] _label;
	bool _cancel = false;
}


/+
class ItemCheckEventArgs: EventArgs
{
	this(int index, CheckState newCheckState, CheckState oldCheckState)
	{
		this._idx = index;
		this._ncs = newCheckState;
		this._ocs = oldCheckState;
	}
	
	
	final CheckState currentValue() // getter
	{
		return _ocs;
	}
	
	
	/+
	final void newValue(CheckState cs) // setter
	{
		_ncs = cs;
	}
	+/
	
	
	final CheckState newValue() // getter
	{
		return _ncs;
	}
	
	
	private:
	int _idx;
	CheckState _ncs, _ocs;
}
+/


class ItemCheckedEventArgs: EventArgs
{
	this(ListViewItem item)
	{
		this._item = item;
	}
	
	
	final ListViewItem item() // getter
	{
		return this._item;
	}
	
	
	private:
	ListViewItem _item;
}


///
class ListView: ControlSuperClass // docmain
{
	///
	static class ListViewItemCollection
	{
		protected this(ListView lv)
		in
		{
			assert(lv.litems is null);
		}
		body
		{
			this.lv = lv;
		}
		
		
		void add(ListViewItem item)
		{
			int ii = -1; // Insert index.
			
			switch(lv.sorting)
			{
				case SortOrder.NONE: // Add to end.
					ii = _items.length;
					break;
				
				case SortOrder.ASCENDING: // Insertion sort.
					for(ii = 0; ii != _items.length; ii++)
					{
						assert(lv._sortproc);
						//if(item < _items[ii])
						if(lv._sortproc(item, _items[ii]) < 0)
							break;
					}
					break;
				
				case SortOrder.DESCENDING: // Insertion sort.
					for(ii = 0; ii != _items.length; ii++)
					{
						assert(lv._sortproc);
						//if(item >= _items[ii])
						if(lv._sortproc(item, _items[ii]) >= 0)
							break;
					}
					break;
				
				default:
					assert(0);
			}
			
			assert(-1 != ii);
			insert(ii, item);
		}
		
		void add(char[] text)
		{
			return add(new ListViewItem(text));
		}
		
		
		// addRange must have special case in case of sorting.
		
		void addRange(ListViewItem[] range)
		{
			foreach(ListViewItem item; range)
			{
				add(item);
			}
		}
		
		/+
		void addRange(Object[] range)
		{
			foreach(Object o; range)
			{
				add(o);
			}
		}
		+/
		
		void addRange(char[][] range)
		{
			foreach(char[] s; range)
			{
				add(s);
			}
		}
		
		
		private:
		
		ListView lv;
		package ListViewItem[] _items;
		
		
		package final bool created() // getter
		{
			return lv && lv.created();
		}
		
		
		package final void doListItems() // DMD 0.125: this member is not accessible when private.
		in
		{
			assert(created);
		}
		body
		{
			int ii;
			foreach(int i, ListViewItem item; _items)
			{
				ii = lv._ins(i, item);
				//assert(-1 != ii);
				assert(i == ii);
				
				/+
				// Add sub items.
				foreach(int subi, ListViewSubItem subItem; item.isubs._subs)
				{
					lv._ins(i, subItem, subi + 1); // Sub items really start at 1 in the list view.
				}
				+/
			}
		}
		
		
		void verifyNoParent(ListViewItem item)
		{
			if(item.lview)
				throw new DflException("ListViewItem already belongs to a ListView");
		}
		
		
		void _added(size_t idx, ListViewItem val)
		{
			verifyNoParent(val);
			
			val.lview = lv;
			
			int i;
			if(created)
			{
				i = lv._ins(idx, val);
				assert(-1 != i);
			}
		}
		
		
		void _removed(size_t idx, ListViewItem val)
		{
			if(size_t.max == idx) // Clear all.
			{
				if(created)
				{
					lv.prevwproc(LVM_DELETEALLITEMS, 0, 0);
				}
			}
			else
			{
				if(created)
				{
					lv.prevwproc(LVM_DELETEITEM, cast(WPARAM)idx, 0);
				}
			}
		}
		
		
		public:
		
		mixin ListWrapArray!(ListViewItem, _items,
			_blankListCallback!(ListViewItem), _added,
			_blankListCallback!(ListViewItem), _removed,
			true, false, false);
	}
	
	
	///
	static class ColumnHeaderCollection
	{
		protected this(ListView owner)
		in
		{
			assert(!owner.cols);
		}
		body
		{
			lv = owner;
		}
		
		
		private:
		ListView lv;
		ColumnHeader[] _headers;
		
		
		package final bool created() // getter
		{
			return lv && lv.created();
		}
		
		
		void verifyNoParent(ColumnHeader header)
		{
			if(header.lview)
				throw new DflException("ColumnHeader already belongs to a ListView");
		}
		
		
		package final void doListHeaders() // DMD 0.125: this member is not accessible when private.
		in
		{
			assert(created);
		}
		body
		{
			int ii;
			foreach(int i, ColumnHeader header; _headers)
			{
				ii = lv._ins(i, header);
				assert(-1 != ii);
				//assert(i == ii);
			}
		}
		
		
		void _added(size_t idx, ColumnHeader val)
		{
			verifyNoParent(val);
			
			val.lview = lv;
			
			int i;
			if(created)
			{
				i = lv._ins(idx, val);
				assert(-1 != i);
			}
		}
		
		
		void _removed(size_t idx, ColumnHeader val)
		{
			if(size_t.max == idx) // Clear all.
			{
			}
			else
			{
				if(created)
				{
					lv.prevwproc(LVM_DELETECOLUMN, cast(WPARAM)idx, 0);
				}
			}
		}
		
		
		public:
		
		mixin ListWrapArray!(ColumnHeader, _headers,
			_blankListCallback!(ColumnHeader), _added,
			_blankListCallback!(ColumnHeader), _removed,
			true, false, false,
			true); // CLEAR_EACH
	}
	
	
	///
	static class SelectedIndexCollection
	{
		deprecated alias length count;
		
		int length() // getter
		{
			if(!lview.created)
				return 0;
			
			int result = 0;
			foreach(int onidx; this)
			{
				result++;
			}
			return result;
		}
		
		
		int opIndex(int idx)
		{
			foreach(int onidx; this)
			{
				if(!idx)
					return onidx;
				idx--;
			}
			
			// If it's not found it's out of bounds and bad things happen.
			assert(0);
			return -1;
		}
		
		
		bool contains(int idx)
		{
			return indexOf(idx) != -1;
		}
		
		
		int indexOf(int idx)
		{
			int i = 0;
			foreach(int onidx; this)
			{
				if(onidx == idx)
					return i;
				i++;
			}
			return -1;
		}
		
		
		int opApply(int delegate(inout int) dg)
		{
			if(!lview.created)
				return 0;
			
			int result = 0;
			int idx = -1;
			for(;;)
			{
				idx = cast(int)lview.prevwproc(LVM_GETNEXTITEM, cast(WPARAM)idx, MAKELPARAM(cast(UINT)LVNI_SELECTED, 0));
				if(-1 == idx) // Done.
					break;
				int dgidx = idx; // Prevent inout.
				result = dg(dgidx);
				if(result)
					break;
			}
			return result;
		}
		
		mixin OpApplyAddIndex!(opApply, int);
		
		
		protected this(ListView lv)
		{
			lview = lv;
		}
		
		
		package:
		ListView lview;
	}
	
	
	deprecated alias SelectedItemCollection SelectedListViewItemCollection;
	
	///
	static class SelectedItemCollection
	{
		deprecated alias length count;
		
		int length() // getter
		{
			if(!lview.created)
				return 0;
			
			int result = 0;
			foreach(ListViewItem onitem; this)
			{
				result++;
			}
			return result;
		}
		
		
		ListViewItem opIndex(int idx)
		{
			foreach(ListViewItem onitem; this)
			{
				if(!idx)
					return onitem;
				idx--;
			}
			
			// If it's not found it's out of bounds and bad things happen.
			assert(0);
			return null;
		}
		
		
		bool contains(ListViewItem item)
		{
			return indexOf(item) != -1;
		}
		
		
		int indexOf(ListViewItem item)
		{
			int i = 0;
			foreach(ListViewItem onitem; this)
			{
				if(onitem == item) // Not using is.
					return i;
				i++;
			}
			return -1;
		}
		
		
		int opApply(int delegate(inout ListViewItem) dg)
		{
			if(!lview.created)
				return 0;
			
			int result = 0;
			int idx = -1;
			for(;;)
			{
				idx = cast(int)lview.prevwproc(LVM_GETNEXTITEM, cast(WPARAM)idx, MAKELPARAM(cast(UINT)LVNI_SELECTED, 0));
				if(-1 == idx) // Done.
					break;
				ListViewItem litem = lview.litems._items[idx]; // Prevent inout.
				result = dg(litem);
				if(result)
					break;
			}
			return result;
		}
		
		mixin OpApplyAddIndex!(opApply, ListViewItem);
		
		
		protected this(ListView lv)
		{
			lview = lv;
		}
		
		
		package:
		ListView lview;
	}
	
	
	///
	static class CheckedIndexCollection
	{
		deprecated alias length count;
		
		int length() // getter
		{
			if(!lview.created)
				return 0;
			
			int result = 0;
			foreach(int onidx; this)
			{
				result++;
			}
			return result;
		}
		
		
		int opIndex(int idx)
		{
			foreach(int onidx; this)
			{
				if(!idx)
					return onidx;
				idx--;
			}
			
			// If it's not found it's out of bounds and bad things happen.
			assert(0);
			return -1;
		}
		
		
		bool contains(int idx)
		{
			return indexOf(idx) != -1;
		}
		
		
		int indexOf(int idx)
		{
			int i = 0;
			foreach(int onidx; this)
			{
				if(onidx == idx)
					return i;
				i++;
			}
			return -1;
		}
		
		
		int opApply(int delegate(inout int) dg)
		{
			if(!lview.created)
				return 0;
			
			int result = 0;
			foreach(inout size_t i, inout ListViewItem lvitem; lview.items)
			{
				if(lvitem._getcheckstate(i))
				{
					int dgidx = i; // Prevent inout.
					result = dg(dgidx);
					if(result)
						break;
				}
			}
			return result;
		}
		
		mixin OpApplyAddIndex!(opApply, int);
		
		
		protected this(ListView lv)
		{
			lview = lv;
		}
		
		
		package:
		ListView lview;
	}
	
	
	this()
	{
		_initListview();
		
		litems = new ListViewItemCollection(this);
		cols = new ColumnHeaderCollection(this);
		selidxcollection = new SelectedIndexCollection(this);
		selobjcollection = new SelectedItemCollection(this);
		checkedis = new CheckedIndexCollection(this);
		
		wstyle |= WS_TABSTOP | LVS_ALIGNTOP | LVS_AUTOARRANGE | LVS_SHAREIMAGELISTS;
		wexstyle |= WS_EX_CLIENTEDGE;
		ctrlStyle |= ControlStyles.SELECTABLE;
		wclassStyle = listviewClassStyle;
	}
	
	
	///
	final void activation(ItemActivation ia) // setter
	{
		switch(ia)
		{
			case ItemActivation.STANDARD:
				_lvexstyle(LVS_EX_ONECLICKACTIVATE | LVS_EX_TWOCLICKACTIVATE, 0);
				break;
			
			case ItemActivation.ONE_CLICK:
				_lvexstyle(LVS_EX_ONECLICKACTIVATE | LVS_EX_TWOCLICKACTIVATE, LVS_EX_ONECLICKACTIVATE);
				break;
			
			case ItemActivation.TWO_CLICK:
				_lvexstyle(LVS_EX_ONECLICKACTIVATE | LVS_EX_TWOCLICKACTIVATE, LVS_EX_TWOCLICKACTIVATE);
				break;
			
			default:
				assert(0);
		}
	}
	
	/// ditto
	final ItemActivation activation() // getter
	{
		DWORD lvex;
		lvex = _lvexstyle();
		if(lvex & LVS_EX_ONECLICKACTIVATE)
			return ItemActivation.ONE_CLICK;
		if(lvex & LVS_EX_TWOCLICKACTIVATE)
			return ItemActivation.TWO_CLICK;
		return ItemActivation.STANDARD;
	}
	
	
	/+
	///
	final void alignment(ListViewAlignment lva)
	{
		// TODO
		
		switch(lva)
		{
			case ListViewAlignment.TOP:
				_style((_style() & ~(LVS_ALIGNLEFT | foo)) | LVS_ALIGNTOP);
				break;
			
			default:
				assert(0);
		}
	}
	
	/// ditto
	final ListViewAlignment alignment() // getter
	{
		// TODO
	}
	+/
	
	
	///
	final void allowColumnReorder(bool byes) // setter
	{
		_lvexstyle(LVS_EX_HEADERDRAGDROP, byes ? LVS_EX_HEADERDRAGDROP : 0);
	}
	
	/// ditto
	final bool allowColumnReorder() // getter
	{
		return (_lvexstyle() & LVS_EX_HEADERDRAGDROP) == LVS_EX_HEADERDRAGDROP;
	}
	
	
	///
	final void autoArrange(bool byes) // setter
	{
		if(byes)
			_style(_style() | LVS_AUTOARRANGE);
		else
			_style(_style() & ~LVS_AUTOARRANGE);
		
		//_crecreate(); // ?
	}
	
	/// ditto
	final bool autoArrange() // getter
	{
		return (_style() & LVS_AUTOARRANGE) == LVS_AUTOARRANGE;
	}
	
	
	override void backColor(Color c) // setter
	{
		if(created)
		{
			COLORREF cref;
			if(Color.empty == c)
				cref = CLR_NONE;
			else
				cref = c.toRgb();
			prevwproc(LVM_SETBKCOLOR, 0, cast(LPARAM)cref);
			prevwproc(LVM_SETTEXTBKCOLOR, 0, cast(LPARAM)cref);
		}
		
		super.backColor = c;
	}
	
	
	override Color backColor() // getter
	{
		if(Color.empty == backc)
			return defaultBackColor;
		return backc;
	}
	
	
	///
	final void borderStyle(BorderStyle bs) // setter
	{
		switch(bs)
		{
			case BorderStyle.FIXED_3D:
				_style(_style() & ~WS_BORDER);
				_exStyle(_exStyle() | WS_EX_CLIENTEDGE);
				break;
				
			case BorderStyle.FIXED_SINGLE:
				_exStyle(_exStyle() & ~WS_EX_CLIENTEDGE);
				_style(_style() | WS_BORDER);
				break;
				
			case BorderStyle.NONE:
				_style(_style() & ~WS_BORDER);
				_exStyle(_exStyle() & ~WS_EX_CLIENTEDGE);
				break;
		}
		
		if(created)
		{
			redrawEntire();
		}
	}
	
	/// ditto
	final BorderStyle borderStyle() // getter
	{
		if(_exStyle() & WS_EX_CLIENTEDGE)
			return BorderStyle.FIXED_3D;
		else if(_style() & WS_BORDER)
			return BorderStyle.FIXED_SINGLE;
		return BorderStyle.NONE;
	}
	
	
	///
	final void checkBoxes(bool byes) // setter
	{
		_lvexstyle(LVS_EX_CHECKBOXES, byes ? LVS_EX_CHECKBOXES : 0);
	}
	
	/// ditto
	final bool checkBoxes() // getter
	{
		return (_lvexstyle() & LVS_EX_CHECKBOXES) == LVS_EX_CHECKBOXES;
	}
	
	
	///
	// ListView.CheckedIndexCollection
	final CheckedIndexCollection checkedIndices() // getter
	{
		return checkedis;
	}
	
	
	/+
	///
	// ListView.CheckedListViewItemCollection
	final CheckedListViewItemCollection checkedItems() // getter
	{
		// TODO
	}
	+/
	
	
	///
	final ColumnHeaderCollection columns() // getter
	{
		return cols;
	}
	
	
	///
	// Extra.
	final int focusedIndex() // getter
	{
		if(!created)
			return -1;
		return cast(int)prevwproc(LVM_GETNEXTITEM, cast(WPARAM)-1, MAKELPARAM(cast(UINT)LVNI_FOCUSED, 0));
	}
	
	
	///
	final ListViewItem focusedItem() // getter
	{
		int i;
		i = focusedIndex;
		if(-1 == i)
			return null;
		return litems._items[i];
	}
	
	
	override void foreColor(Color c) // setter
	{
		if(created)
			prevwproc(LVM_SETTEXTCOLOR, 0, cast(LPARAM)c.toRgb());
		
		super.foreColor = c;
	}
	
	
	override Color foreColor() // getter
	{
		if(Color.empty == forec)
			return defaultForeColor;
		return forec;
	}
	
	
	///
	final void fullRowSelect(bool byes) // setter
	{
		_lvexstyle(LVS_EX_FULLROWSELECT, byes ? LVS_EX_FULLROWSELECT : 0);
	}
	
	/// ditto
	final bool fullRowSelect() // getter
	{
		return (_lvexstyle() & LVS_EX_FULLROWSELECT) == LVS_EX_FULLROWSELECT;
	}
	
	
	///
	final void gridLines(bool byes) // setter
	{
		_lvexstyle(LVS_EX_GRIDLINES, byes ? LVS_EX_GRIDLINES : 0);
	}
	
	/// ditto
	final bool gridLines() // getter
	{
		return (_lvexstyle() & LVS_EX_GRIDLINES) == LVS_EX_GRIDLINES;
	}
	
	
	/+
	///
	final void headerStyle(ColumnHeaderStyle chs) // setter
	{
		// TODO: LVS_NOCOLUMNHEADER ... default is clickable.
	}
	
	/// ditto
	final ColumnHeaderStyle headerStyle() // getter
	{
		// TODO
	}
	+/
	
	
	///
	final void hideSelection(bool byes) // setter
	{
		if(byes)
			_style(_style() & ~LVS_SHOWSELALWAYS);
		else
			_style(_style() | LVS_SHOWSELALWAYS);
	}
	
	/// ditto
	final bool hideSelection() // getter
	{
		return (_style() & LVS_SHOWSELALWAYS) != LVS_SHOWSELALWAYS;
	}
	
	
	///
	final void hoverSelection(bool byes) // setter
	{
		_lvexstyle(LVS_EX_TRACKSELECT, byes ? LVS_EX_TRACKSELECT : 0);
	}
	
	/// ditto
	final bool hoverSelection() // getter
	{
		return (_lvexstyle() & LVS_EX_TRACKSELECT) == LVS_EX_TRACKSELECT;
	}
	
	
	///
	final ListViewItemCollection items() // getter
	{
		return litems;
	}
	
	
	///
	// Simple as addRow("item", "sub item1", "sub item2", "etc");
	// rowstrings[0] is the item and rowstrings[1 .. rowstrings.length] are its sub items.
	//final void addRow(char[][] rowstrings ...)
	final ListViewItem addRow(char[][] rowstrings ...)
	{
		if(rowstrings.length)
		{
			ListViewItem item;
			item = new ListViewItem(rowstrings[0]);
			if(rowstrings.length > 1)
				item.subItems.addRange(rowstrings[1 .. rowstrings.length]);
			items.add(item);
			return item;
		}
		assert(0);
		return null;
	}
	
	
	///
	final void labelEdit(bool byes) // setter
	{
		if(byes)
			_style(_style() | LVS_EDITLABELS);
		else
			_style(_style() & ~LVS_EDITLABELS);
	}
	
	/// ditto
	final bool labelEdit() // getter
	{
		return (_style() & LVS_EDITLABELS) == LVS_EDITLABELS;
	}
	
	
	///
	final void labelWrap(bool byes) // setter
	{
		if(byes)
			_style(_style() & ~LVS_NOLABELWRAP);
		else
			_style(_style() | LVS_NOLABELWRAP);
	}
	
	/// ditto
	final bool labelWrap() // getter
	{
		return (_style() & LVS_NOLABELWRAP) != LVS_NOLABELWRAP;
	}
	
	
	///
	final void multiSelect(bool byes) // setter
	{
		if(byes)
		{
			_style(_style() & ~LVS_SINGLESEL);
		}
		else
		{
			_style(_style() | LVS_SINGLESEL);
			
			if(selectedItems.length > 1)
				selectedItems[0].selected = true; // Clear all but first selected.
		}
	}
	
	/// ditto
	final bool multiSelect() // getter
	{
		return (_style() & LVS_SINGLESEL) != LVS_SINGLESEL;
	}
	
	
	///
	// Note: scrollable=false is not compatible with the list or details(report) styles(views).
	// See Knowledge Base Article Q137520.
	final void scrollable(bool byes) // setter
	{
		if(byes)
			_style(_style() & ~LVS_NOSCROLL);
		else
			_style(_style() | LVS_NOSCROLL);
		
		_crecreate();
	}
	
	/// ditto
	final bool scrollable() // getter
	{
		return (_style() & LVS_NOSCROLL) != LVS_NOSCROLL;
	}
	
	
	///
	final SelectedIndexCollection selectedIndices() // getter
	{
		return selidxcollection;
	}
	
	
	///
	final SelectedItemCollection selectedItems() // getter
	{
		return selobjcollection;
	}
	
	
	///
	final void view(View v) // setter
	{
		switch(v)
		{
			case View.LARGE_ICON:
				_style(_style() & ~(LVS_SMALLICON | LVS_LIST | LVS_REPORT));
				break;
			
			case View.SMALL_ICON:
				_style((_style() & ~(LVS_LIST | LVS_REPORT)) | LVS_SMALLICON);
				break;
			
			case View.LIST:
				_style((_style() & ~(LVS_SMALLICON | LVS_REPORT)) | LVS_LIST);
				break;
			
			case View.DETAILS:
				_style((_style() & ~(LVS_SMALLICON | LVS_LIST)) | LVS_REPORT);
				break;
			
			default:
				assert(0);
		}
		
		if(created)
			redrawEntire();
	}
	
	/// ditto
	final View view() // getter
	{
		LONG st;
		st = _style();
		if(st & LVS_SMALLICON)
			return View.SMALL_ICON;
		if(st & LVS_LIST)
			return View.LIST;
		if(st & LVS_REPORT)
			return View.DETAILS;
		return View.LARGE_ICON;
	}
	
	
	///
	final void sorting(SortOrder so) // setter
	{
		if(so == _sortorder)
			return;
		
		switch(so)
		{
			case SortOrder.NONE:
				_sortproc = null;
				break;
			
			case SortOrder.ASCENDING:
			case SortOrder.DESCENDING:
				if(!_sortproc)
					_sortproc = &_defsortproc;
				break;
			
			default:
				assert(0);
		}
		
		_sortorder = so;
		
		sort();
	}
	
	/// ditto
	final SortOrder sorting() // getter
	{
		return _sortorder;
	}
	
	
	///
	final void sort()
	{
		if(SortOrder.NONE != _sortorder)
		{
			assert(_sortproc);
			ListViewItem[] sitems = items._items;
			if(sitems.length > 1)
			{
				sitems = sitems.dup; // So exception won't damage anything.
				// Stupid bubble sort. At least it's a "stable sort".
				bool swp;
				auto sortmax = sitems.length - 1;
				size_t iw;
				do
				{
					swp = false;
					for(iw = 0; iw != sortmax; iw++)
					{
						//if(sitems[iw] > sitems[iw + 1])
						if(_sortproc(sitems[iw], sitems[iw + 1]) > 0)
						{
							swp = true;
							ListViewItem lvis = sitems[iw];
							sitems[iw] = sitems[iw + 1];
							sitems[iw + 1] = lvis;
						}
					}
				}
				while(swp);
				
				if(created)
				{
					beginUpdate();
					SendMessageA(handle, LVM_DELETEALLITEMS, 0, 0); // Note: this sends LVN_DELETEALLITEMS.
					foreach(idx, lvi; sitems)
					{
						_ins(idx, lvi);
					}
					endUpdate();
				}
				
				items._items = sitems;
			}
		}
	}
	
	
	///
	final void sorter(int delegate(ListViewItem, ListViewItem) sortproc) // setter
	{
		if(sortproc == this._sortproc)
			return;
		
		if(!sortproc)
		{
			this._sortproc = null;
			sorting = SortOrder.NONE;
			return;
		}
		
		this._sortproc = sortproc;
		
		if(SortOrder.NONE == sorting)
			sorting = SortOrder.ASCENDING;
		sort();
	}
	
	/// ditto
	final int delegate(ListViewItem, ListViewItem) sorter() // getter
	{
		return _sortproc;
	}
	
	
	/+
	///
	// Gets the first visible item.
	final ListViewItem topItem() // getter
	{
		if(!created)
			return null;
		// TODO: LVM_GETTOPINDEX
	}
	+/
	
	
	///
	final void arrangeIcons()
	{
		if(created)
		//	SendMessageA(hwnd, LVM_ARRANGE, LVA_DEFAULT, 0);
			prevwproc(LVM_ARRANGE, LVA_DEFAULT, 0);
	}
	
	/// ditto
	final void arrangeIcons(ListViewAlignment a)
	{
		if(created)
		{
			switch(a)
			{
				case ListViewAlignment.TOP:
					//SendMessageA(hwnd, LVM_ARRANGE, LVA_ALIGNTOP, 0);
					prevwproc(LVM_ARRANGE, LVA_ALIGNTOP, 0);
					break;
				
				case ListViewAlignment.DEFAULT:
					//SendMessageA(hwnd, LVM_ARRANGE, LVA_DEFAULT, 0);
					prevwproc(LVM_ARRANGE, LVA_DEFAULT, 0);
					break;
				
				case ListViewAlignment.LEFT:
					//SendMessageA(hwnd, LVM_ARRANGE, LVA_ALIGNLEFT, 0);
					prevwproc(LVM_ARRANGE, LVA_ALIGNLEFT, 0);
					break;
				
				case ListViewAlignment.SNAP_TO_GRID:
					//SendMessageA(hwnd, LVM_ARRANGE, LVA_SNAPTOGRID, 0);
					prevwproc(LVM_ARRANGE, LVA_SNAPTOGRID, 0);
					break;
				
				default:
					assert(0);
			}
		}
	}
	
	
	///
	final void beginUpdate()
	{
		SendMessageA(handle, WM_SETREDRAW, false, 0);
	}
	
	/// ditto
	final void endUpdate()
	{
		SendMessageA(handle, WM_SETREDRAW, true, 0);
		invalidate(true); // Show updates.
	}
	
	
	///
	final void clear()
	{
		litems.clear();
	}
	
	
	///
	final void ensureVisible(int index)
	{
		// Can only be visible if it's created. Check if correct implementation.
		createControl();
		
		//if(created)
		//	SendMessageA(hwnd, LVM_ENSUREVISIBLE, cast(WPARAM)index, FALSE);
			prevwproc(LVM_ENSUREVISIBLE, cast(WPARAM)index, FALSE);
	}
	
	
	/+
	///
	// Returns null if no item is at this location.
	final ListViewItem getItemAt(int x, int y)
	{
		// LVM_FINDITEM LVFI_NEARESTXY ? since it's nearest, need to see if it's really at that location.
		// TODO
	}
	+/
	
	
	///
	final Rect getItemRect(int index)
	{
		if(created)
		{
			RECT rect;
			rect.left = LVIR_BOUNDS;
			if(prevwproc(LVM_GETITEMRECT, cast(WPARAM)index, cast(LPARAM)&rect))
				return Rect(&rect);
		}
		return Rect(0, 0, 0, 0);
	}
	
	/// ditto
	final Rect getItemRect(int index, ItemBoundsPortion ibp)
	{
		if(created)
		{
			RECT rect;
			switch(ibp)
			{
				case ItemBoundsPortion.ENTIRE:
					rect.left = LVIR_BOUNDS;
					break;
				
				case ItemBoundsPortion.ICON:
					rect.left = LVIR_ICON;
					break;
				
				case ItemBoundsPortion.ITEM_ONLY:
					rect.left = LVIR_SELECTBOUNDS; // ?
					break;
				
				case ItemBoundsPortion.LABEL:
					rect.left = LVIR_LABEL;
					break;
				
				default:
					assert(0);
			}
			if(prevwproc(LVM_GETITEMRECT, cast(WPARAM)index, cast(LPARAM)&rect))
				return Rect(&rect);
		}
		return Rect(0, 0, 0, 0);
	}
	
	
	version(DFL_NO_IMAGELIST)
	{
	}
	else
	{
		///
		final void largeImageList(ImageList imglist) // setter
		{
			if(isHandleCreated)
			{
				prevwproc(LVM_SETIMAGELIST, LVSIL_NORMAL,
					cast(LPARAM)(imglist ? imglist.handle : cast(HIMAGELIST)null));
			}
			
			_lgimglist = imglist;
		}
		
		/// ditto
		final ImageList largeImageList() // getter
		{
			return _lgimglist;
		}
		
		
		///
		final void smallImageList(ImageList imglist) // setter
		{
			if(isHandleCreated)
			{
				prevwproc(LVM_SETIMAGELIST, LVSIL_SMALL,
					cast(LPARAM)(imglist ? imglist.handle : cast(HIMAGELIST)null));
			}
			
			_smimglist = imglist;
		}
		
		/// ditto
		final ImageList smallImageList() // getter
		{
			return _smimglist;
		}
		
		
		/+
		///
		final void stateImageList(ImageList imglist) // setter
		{
			if(isHandleCreated)
			{
				prevwproc(LVM_SETIMAGELIST, LVSIL_STATE,
					cast(LPARAM)(imglist ? imglist.handle : cast(HIMAGELIST)null));
			}
			
			_stimglist = imglist;
		}
		
		/// ditto
		final ImageList stateImageList() // getter
		{
			return _stimglist;
		}
		+/
	}
	
	
	// TODO:
	//  itemActivate, itemDrag
	//CancelEventHandler selectedIndexChanging; // ?
	
	Event!(ListView, ColumnClickEventArgs) columnClick; ///
	Event!(ListView, LabelEditEventArgs) afterLabelEdit; ///
	Event!(ListView, LabelEditEventArgs) beforeLabelEdit; ///
	//Event!(ListView, ItemCheckEventArgs) itemCheck; ///
	Event!(ListView, ItemCheckedEventArgs) itemChecked; ///
	Event!(ListView, EventArgs) selectedIndexChanged; ///
	
	
	///
	protected void onColumnClick(ColumnClickEventArgs ea)
	{
		columnClick(this, ea);
	}
	
	
	///
	protected void onAfterLabelEdit(LabelEditEventArgs ea)
	{
		afterLabelEdit(this, ea);
	}
	
	
	///
	protected void onBeforeLabelEdit(LabelEditEventArgs ea)
	{
		beforeLabelEdit(this, ea);
	}
	
	
	/+
	protected void onItemCheck(ItemCheckEventArgs ea)
	{
		itemCheck(this, ea);
	}
	+/
	
	
	///
	protected void onItemChecked(ItemCheckedEventArgs ea)
	{
		itemChecked(this, ea);
	}
	
	
	///
	protected void onSelectedIndexChanged(EventArgs ea)
	{
		selectedIndexChanged(this, ea);
	}
	
	
	protected override Size defaultSize() // getter
	{
		return Size(120, 95);
	}
	
	
	static Color defaultBackColor() // getter
	{
		return SystemColors.window;
	}
	
	
	static Color defaultForeColor() // getter
	{
		return SystemColors.windowText;
	}
	
	
	protected override void createParams(inout CreateParams cp)
	{
		super.createParams(cp);
		
		cp.className = LISTVIEW_CLASSNAME;
	}
	
	
	protected override void prevWndProc(inout Message msg)
	{
		switch(msg.msg)
		{
			case WM_MOUSEHOVER:
				if(!hoverSelection)
					return;
				break;
			
			default: ;
		}
		
		//msg.result = CallWindowProcA(listviewPrevWndProc, msg.hWnd, msg.msg, msg.wParam, msg.lParam);
		msg.result = dfl.internal.utf.callWindowProc(listviewPrevWndProc, msg.hWnd, msg.msg, msg.wParam, msg.lParam);
	}
	
	
	protected override void wndProc(inout Message m)
	{
		// TODO: support the listview messages.
		
		switch(m.msg)
		{
			/+
			case WM_PAINT:
				// This seems to be the only way to display columns correctly.
				prevWndProc(m);
				return;
			+/
			
			case LVM_ARRANGE:
				m.result = FALSE;
				return;
			
			case LVM_DELETEALLITEMS:
				litems.clear();
				m.result = TRUE;
				return;
			
			case LVM_DELETECOLUMN:
				cols.removeAt(cast(int)m.wParam);
				m.result = TRUE;
				return;
			
			case LVM_DELETEITEM:
				litems.removeAt(cast(int)m.wParam);
				m.result = TRUE;
				return;
			
			case LVM_INSERTCOLUMNA:
			case LVM_INSERTCOLUMNW:
				m.result = -1;
				return;
			
			case LVM_INSERTITEMA:
			case LVM_INSERTITEMW:
				m.result = -1;
				return;
			
			case LVM_SETBKCOLOR:
				backColor = Color.fromRgb(cast(COLORREF)m.lParam);
				m.result = TRUE;
				return;
			
			case LVM_SETCALLBACKMASK:
				m.result = FALSE;
				return;
			
			case LVM_SETCOLUMNA:
			case LVM_SETCOLUMNW:
				m.result = FALSE;
				return;
			
			case LVM_SETCOLUMNWIDTH:
				return;
			
			case LVM_SETIMAGELIST:
				m.result = cast(LRESULT)null;
				return;
			
			case LVM_SETITEMA:
				m.result = FALSE;
				return;
			
			case LVM_SETITEMSTATE:
				m.result = FALSE;
				return;
			
			case LVM_SETITEMTEXTA:
			case LVM_SETITEMTEXTW:
				m.result = FALSE;
				return;
			
			//case LVM_SETTEXTBKCOLOR:
			
			case LVM_SETTEXTCOLOR:
				foreColor = Color.fromRgb(cast(COLORREF)m.lParam);
				m.result = TRUE;
				return;
			
			case LVM_SORTITEMS:
				m.result = FALSE;
				return;
			
			default: ;
		}
		super.wndProc(m);
	}
	
	
	protected override void onHandleCreated(EventArgs ea)
	{
		super.onHandleCreated(ea);
		
		//SendMessageA(hwnd, LVM_SETEXTENDEDLISTVIEWSTYLE, wlvexstyle, wlvexstyle);
		prevwproc(LVM_SETEXTENDEDLISTVIEWSTYLE, 0, wlvexstyle); // wparam=0 sets all.
		
		Color color;
		COLORREF cref;
		
		color = backColor;
		if(Color.empty == color)
			cref = CLR_NONE;
		else
			cref = color.toRgb();
		prevwproc(LVM_SETBKCOLOR, 0, cast(LPARAM)cref);
		prevwproc(LVM_SETTEXTBKCOLOR, 0, cast(LPARAM)cref);
		
		//prevwproc(LVM_SETTEXTCOLOR, 0, foreColor.toRgb()); // DMD 0.125: cast(Control )(this).foreColor() is not an lvalue
		color = foreColor;
		prevwproc(LVM_SETTEXTCOLOR, 0, cast(LPARAM)color.toRgb());
		
		version(DFL_NO_IMAGELIST)
		{
		}
		else
		{
			if(_lgimglist)
				prevwproc(LVM_SETIMAGELIST, LVSIL_NORMAL, cast(LPARAM)_lgimglist.handle);
			if(_smimglist)
				prevwproc(LVM_SETIMAGELIST, LVSIL_SMALL, cast(LPARAM)_smimglist.handle);
			//if(_stimglist)
			//	prevwproc(LVM_SETIMAGELIST, LVSIL_STATE, cast(LPARAM)_stimglist.handle);
		}
		
		cols.doListHeaders();
		litems.doListItems();
		
		recalcEntire(); // Fix frame.
	}
	
	
	protected override void onReflectedMessage(inout Message m)
	{
		super.onReflectedMessage(m);
		
		switch(m.msg)
		{
			case WM_NOTIFY:
				{
					NMHDR* nmh;
					nmh = cast(NMHDR*)m.lParam;
					switch(nmh.code)
					{
						case LVN_GETDISPINFOA:
							if(dfl.internal.utf.useUnicode)
								break;
							{
								LV_DISPINFOA* lvdi;
								lvdi = cast(LV_DISPINFOA*)nmh;
								
								// Note: might want to verify it's a valid ListViewItem.
								
								ListViewItem item;
								item = cast(ListViewItem)cast(void*)lvdi.item.lParam;
								
								if(!lvdi.item.iSubItem) // Item.
								{
									version(DFL_NO_IMAGELIST)
									{
									}
									else
									{
										if(lvdi.item.mask & LVIF_IMAGE)
											lvdi.item.iImage = item._imgidx;
									}
									
									if(lvdi.item.mask & LVIF_TEXT)
										lvdi.item.pszText = item.calltxt.ansi;
								}
								else // Sub item.
								{
									if(lvdi.item.mask & LVIF_TEXT)
									{
										if(lvdi.item.iSubItem <= item.subItems.length)
											lvdi.item.pszText = item.subItems[lvdi.item.iSubItem - 1].calltxt.ansi;
									}
								}
							}
							break;
						
						case LVN_GETDISPINFOW:
							{
								char[] text;
								LV_DISPINFOW* lvdi;
								lvdi = cast(LV_DISPINFOW*)nmh;
								
								// Note: might want to verify it's a valid ListViewItem.
								
								ListViewItem item;
								item = cast(ListViewItem)cast(void*)lvdi.item.lParam;
								
								if(!lvdi.item.iSubItem) // Item.
								{
									version(DFL_NO_IMAGELIST)
									{
									}
									else
									{
										if(lvdi.item.mask & LVIF_IMAGE)
											lvdi.item.iImage = item._imgidx;
									}
									
									if(lvdi.item.mask & LVIF_TEXT)
										lvdi.item.pszText = item.calltxt.unicode;
								}
								else // Sub item.
								{
									if(lvdi.item.mask & LVIF_TEXT)
									{
										if(lvdi.item.iSubItem <= item.subItems.length)
											lvdi.item.pszText = item.subItems[lvdi.item.iSubItem - 1].calltxt.unicode;
									}
								}
							}
							break;
						
						/+
						case LVN_ITEMCHANGING:
							{
								auto nmlv = cast(NM_LISTVIEW*)nmh;
								if(-1 != nmlv.iItem)
								{
									UINT stchg = nmlv.uNewState ^ nmlv.uOldState;
									if(stchg & (3 << 12))
									{
										// Note: not tested.
										scope ItemCheckEventArgs ea = new ItemCheckEventArgs(nmlv.iItem,
											(((nmlv.uNewState >> 12) & 3) - 1) ? CheckState.CHECKED : CheckState.UNCHECKED,
											(((nmlv.uOldState >> 12) & 3) - 1) ? CheckState.CHECKED : CheckState.UNCHECKED);
										onItemCheck(ea);
									}
								}
							}
							break;
						+/
						
						case LVN_ITEMCHANGED:
							{
								auto nmlv = cast(NM_LISTVIEW*)nmh;
								if(-1 != nmlv.iItem)
								{
									if(nmlv.uChanged & LVIF_STATE)
									{
										UINT stchg = nmlv.uNewState ^ nmlv.uOldState;
										
										//if(stchg & LVIS_SELECTED)
										{
											// Only fire for the selected one; don't fire twice for old/new.
											if(nmlv.uNewState & LVIS_SELECTED)
											{
												onSelectedIndexChanged(EventArgs.empty);
											}
										}
										
										if(stchg & (3 << 12))
										{
											scope ItemCheckedEventArgs ea = new ItemCheckedEventArgs(items[nmlv.iItem]);
											onItemChecked(ea);
										}
									}
								}
							}
							break;
						
						case LVN_COLUMNCLICK:
							{
								auto nmlv = cast(NM_LISTVIEW*)nmh;
								scope ccea = new ColumnClickEventArgs(nmlv.iSubItem);
								onColumnClick(ccea);
							}
							break;
						
						case LVN_BEGINLABELEDITW:
							goto begin_label_edit;
						
						case LVN_BEGINLABELEDITA:
							if(dfl.internal.utf.useUnicode)
								break;
							begin_label_edit:
							
							{
								LV_DISPINFOA* nmdi;
								nmdi = cast(LV_DISPINFOA*)nmh;
								if(nmdi.item.iSubItem)
								{
									m.result = TRUE;
									break;
								}
								ListViewItem lvitem;
								lvitem = cast(ListViewItem)cast(void*)nmdi.item.lParam;
								scope LabelEditEventArgs leea = new LabelEditEventArgs(lvitem);
								onBeforeLabelEdit(leea);
								m.result = leea.cancelEdit;
							}
							break;
						
						case LVN_ENDLABELEDITW:
							{
								char[] label;
								LV_DISPINFOW* nmdi;
								nmdi = cast(LV_DISPINFOW*)nmh;
								if(nmdi.item.pszText)
								{
									ListViewItem lvitem;
									lvitem = cast(ListViewItem)cast(void*)nmdi.item.lParam;
									if(nmdi.item.iSubItem)
									{
										m.result = FALSE;
										break;
									}
									label = fromUnicodez(nmdi.item.pszText);
									scope LabelEditEventArgs nleea = new LabelEditEventArgs(lvitem, label);
									onAfterLabelEdit(nleea);
									if(nleea.cancelEdit)
									{
										m.result = FALSE;
									}
									else
									{
										// TODO: check if correct implementation.
										// Update the lvitem's cached text..
										lvitem.settextin(label);
										
										m.result = TRUE;
									}
								}
							}
							break;
						
						case LVN_ENDLABELEDITA:
							if(dfl.internal.utf.useUnicode)
								break;
							{
								char[] label;
								LV_DISPINFOA* nmdi;
								nmdi = cast(LV_DISPINFOA*)nmh;
								if(nmdi.item.pszText)
								{
									ListViewItem lvitem;
									lvitem = cast(ListViewItem)cast(void*)nmdi.item.lParam;
									if(nmdi.item.iSubItem)
									{
										m.result = FALSE;
										break;
									}
									label = fromAnsiz(nmdi.item.pszText);
									scope LabelEditEventArgs nleea = new LabelEditEventArgs(lvitem, label);
									onAfterLabelEdit(nleea);
									if(nleea.cancelEdit)
									{
										m.result = FALSE;
									}
									else
									{
										// TODO: check if correct implementation.
										// Update the lvitem's cached text..
										lvitem.settextin(label);
										
										m.result = TRUE;
									}
								}
							}
							break;
						
						default: ;
					}
				}
				break;
			
			default: ;
		}
	}
	
	
	private:
	DWORD wlvexstyle = 0;
	ListViewItemCollection litems;
	ColumnHeaderCollection cols;
	SelectedIndexCollection selidxcollection;
	SelectedItemCollection selobjcollection;
	SortOrder _sortorder = SortOrder.NONE;
	CheckedIndexCollection checkedis;
	int delegate(ListViewItem, ListViewItem) _sortproc;
	version(DFL_NO_IMAGELIST)
	{
	}
	else
	{
		ImageList _lgimglist, _smimglist;
		//ImageList _stimglist;
	}
	
	
	int _defsortproc(ListViewItem a, ListViewItem b)
	{
		return a.opCmp(b);
	}
	
	
	DWORD _lvexstyle()
	{
		//if(created)
		//	wlvexstyle = cast(DWORD)SendMessageA(hwnd, LVM_GETEXTENDEDLISTVIEWSTYLE, 0, 0);
		//	wlvexstyle = cast(DWORD)prevwproc(LVM_GETEXTENDEDLISTVIEWSTYLE, 0, 0);
		return wlvexstyle;
	}
	
	
	void _lvexstyle(DWORD flags)
	{
		DWORD _b4;
		_b4 = wlvexstyle;
		
		wlvexstyle = flags;
		if(created)
		{
			// hwnd, msg, mask, flags
			//SendMessageA(hwnd, LVM_SETEXTENDEDLISTVIEWSTYLE, flags ^ _b4, wlvexstyle);
			prevwproc(LVM_SETEXTENDEDLISTVIEWSTYLE, flags ^ _b4, wlvexstyle);
			//redrawEntire(); // Need to recalc the frame ?
		}
	}
	
	
	void _lvexstyle(DWORD mask, DWORD flags)
	in
	{
		assert(mask);
	}
	body
	{
		wlvexstyle = (wlvexstyle & ~mask) | (flags & mask);
		if(created)
		{
			// hwnd, msg, mask, flags
			//SendMessageA(hwnd, LVM_SETEXTENDEDLISTVIEWSTYLE, mask, flags);
			prevwproc(LVM_SETEXTENDEDLISTVIEWSTYLE, mask, flags);
			//redrawEntire(); // Need to recalc the frame ?
		}
	}
	
	
	// If -subItemIndex- is 0 it's an item not a sub item.
	// Returns the insertion index or -1 on failure.
	package final LRESULT _ins(int index, LPARAM lparam, char[] itemText, int subItemIndex, int imageIndex = -1)
	in
	{
		assert(created);
	}
	body
	{
		/+
		printf("^ Insert item:  index=%d, lparam=0x%X, text='%.*s', subItemIndex=%d\n",
			index, lparam, itemText.length > 20 ? 20 : itemText.length, cast(char*)itemText, subItemIndex);
		+/
		
		LV_ITEMA lvi;
		lvi.mask = LVIF_TEXT | LVIF_PARAM;
		version(DFL_NO_IMAGELIST)
		{
		}
		else
		{
			//if(-1 != imageIndex)
			if(!subItemIndex)
				lvi.mask |= LVIF_IMAGE;
			//lvi.iImage = imageIndex;
			lvi.iImage = I_IMAGECALLBACK;
		}
		lvi.iItem = index;
		lvi.iSubItem = subItemIndex;
		//lvi.pszText = toStringz(itemText);
		lvi.pszText = LPSTR_TEXTCALLBACKA;
		lvi.lParam = lparam;
		return prevwproc(LVM_INSERTITEMA, 0, cast(LPARAM)&lvi);
	}
	
	
	package final LRESULT _ins(int index, ListViewItem item)
	{
		//return _ins(index, cast(LPARAM)cast(void*)item, item.text, 0);
		version(DFL_NO_IMAGELIST)
		{
			return _ins(index, cast(LPARAM)cast(void*)item, item.text, 0, -1);
		}
		else
		{
			return _ins(index, cast(LPARAM)cast(void*)item, item.text, 0, item._imgidx);
		}
	}
	
	
	package final LRESULT _ins(int index, ListViewSubItem subItem, int subItemIndex)
	in
	{
		assert(subItemIndex > 0);
	}
	body
	{
		return _ins(index, cast(LPARAM)cast(void*)subItem, subItem.text, subItemIndex);
	}
	
	
	package final LRESULT _ins(int index, ColumnHeader header)
	{
		// TODO: column inserted at index 0 can only be left aligned, so will need to
		// insert a dummy column to change the alignment, then delete the dummy column.
		
		//LV_COLUMNA lvc;
		LvColumn lvc;
		lvc.mask = LVCF_FMT | LVCF_SUBITEM | LVCF_TEXT | LVCF_WIDTH;
		switch(header.textAlign)
		{
			case HorizontalAlignment.RIGHT:
				lvc.fmt = LVCFMT_RIGHT;
				break;
			
			case HorizontalAlignment.CENTER:
				lvc.fmt = LVCFMT_CENTER;
				break;
			
			default:
				lvc.fmt = LVCFMT_LEFT;
		}
		lvc.cx = header.width;
		lvc.iSubItem = index; // iSubItem is probably only used when retrieving column info.
		if(dfl.internal.utf.useUnicode)
		{
			lvc.lvcw.pszText = dfl.internal.utf.toUnicodez(header.text);
			return prevwproc(LVM_INSERTCOLUMNW, cast(WPARAM)index, cast(LPARAM)&lvc.lvcw);
		}
		else
		{
			lvc.lvca.pszText = dfl.internal.utf.toAnsiz(header.text);
			return prevwproc(LVM_INSERTCOLUMNA, cast(WPARAM)index, cast(LPARAM)&lvc.lvca);
		}
	}
	
	
	// If -subItemIndex- is 0 it's an item not a sub item.
	// Returns FALSE on failure.
	LRESULT updateItem(int index)
	in
	{
		assert(created);
	}
	body
	{
		return prevwproc(LVM_REDRAWITEMS, cast(WPARAM)index, cast(LPARAM)index);
	}
	
	LRESULT updateItem(ListViewItem item)
	{
		int index;
		index = item.index;
		assert(-1 != index);
		return updateItem(index);
	}
	
	
	LRESULT updateItemText(int index, char[] newText, int subItemIndex = 0)
	{
		return updateItem(index);
	}
	
	LRESULT updateItemText(ListViewItem item, char[] newText, int subItemIndex = 0)
	{
		return updateItem(item);
	}
	
	
	LRESULT updateColumnText(int colIndex, char[] newText)
	{
		//LV_COLUMNA lvc;
		LvColumn lvc;
		
		lvc.mask = LVCF_TEXT;
		if(dfl.internal.utf.useUnicode)
		{
			lvc.lvcw.pszText = dfl.internal.utf.toUnicodez(newText);
			return prevwproc(LVM_SETCOLUMNW, cast(WPARAM)colIndex, cast(LPARAM)&lvc.lvcw);
		}
		else
		{
			lvc.lvca.pszText = dfl.internal.utf.toAnsiz(newText);
			return prevwproc(LVM_SETCOLUMNA, cast(WPARAM)colIndex, cast(LPARAM)&lvc.lvca);
		}
	}
	
	
	LRESULT updateColumnText(ColumnHeader col, char[] newText)
	{
		int colIndex;
		colIndex = columns.indexOf(col);
		assert(-1 != colIndex);
		return updateColumnText(colIndex, newText);
	}
	
	
	LRESULT updateColumnAlign(int colIndex, HorizontalAlignment halign)
	{
		LV_COLUMNA lvc;
		lvc.mask = LVCF_FMT;
		switch(halign)
		{
			case HorizontalAlignment.RIGHT:
				lvc.fmt = LVCFMT_RIGHT;
				break;
			
			case HorizontalAlignment.CENTER:
				lvc.fmt = LVCFMT_CENTER;
				break;
			
			default:
				lvc.fmt = LVCFMT_LEFT;
		}
		return prevwproc(LVM_SETCOLUMNA, cast(WPARAM)colIndex, cast(LPARAM)&lvc);
	}
	
	
	LRESULT updateColumnAlign(ColumnHeader col, HorizontalAlignment halign)
	{
		int colIndex;
		colIndex = columns.indexOf(col);
		assert(-1 != colIndex);
		return updateColumnAlign(colIndex, halign);
	}
	
	
	LRESULT updateColumnWidth(int colIndex, int w)
	{
		LV_COLUMNA lvc;
		lvc.mask = LVCF_WIDTH;
		lvc.cx = w;
		return prevwproc(LVM_SETCOLUMNA, cast(WPARAM)colIndex, cast(LPARAM)&lvc);
	}
	
	
	LRESULT updateColumnWidth(ColumnHeader col, int w)
	{
		int colIndex;
		colIndex = columns.indexOf(col);
		assert(-1 != colIndex);
		return updateColumnWidth(colIndex, w);
	}
	
	
	int getColumnWidth(int colIndex)
	{
		LV_COLUMNA lvc;
		lvc.mask = LVCF_WIDTH;
		lvc.cx = -1;
		prevwproc(LVM_GETCOLUMNA, cast(WPARAM)colIndex, cast(LPARAM)&lvc);
		return lvc.cx;
	}
	
	
	int getColumnWidth(ColumnHeader col)
	{
		int colIndex;
		colIndex = columns.indexOf(col);
		assert(-1 != colIndex);
		return getColumnWidth(colIndex);
	}
	
	
	package:
	final:
	LRESULT prevwproc(UINT msg, WPARAM wparam, LPARAM lparam)
	{
		//return CallWindowProcA(listviewPrevWndProc, hwnd, msg, wparam, lparam);
		return dfl.internal.utf.callWindowProc(listviewPrevWndProc, hwnd, msg, wparam, lparam);
	}
}

