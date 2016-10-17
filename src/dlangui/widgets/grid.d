// Written in the D programming language.

/**

This module contains implementation of grid widgets


GridWidgetBase - abstract grid widget

StringGridWidget - grid of strings


Synopsis:

----
import dlangui.widgets.grid;

StringGridWidget grid = new StringGridWidget("GRID1");
grid.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
grid.showColHeaders = true;
grid.showRowHeaders = true;
grid.resize(30, 50);
grid.fixedCols = 3;
grid.fixedRows = 2;
//grid.rowSelect = true; // testing full row selection
grid.selectCell(4, 6, false);
// create sample grid content
for (int y = 0; y < grid.rows; y++) {
    for (int x = 0; x < grid.cols; x++) {
        grid.setCellText(x, y, "cell("d ~ to!dstring(x + 1) ~ ","d ~ to!dstring(y + 1) ~ ")"d);
    }
    grid.setRowTitle(y, to!dstring(y + 1));
}
for (int x = 0; x < grid.cols; x++) {
    int col = x + 1;
    dstring res;
    int n1 = col / 26;
    int n2 = col % 26;
    if (n1)
        res ~= n1 + 'A';
    res ~= n2 + 'A';
    grid.setColTitle(x, res);
}
grid.autoFit();


----

Copyright: Vadim Lopatin, 2014
License:   Boost License 1.0
Authors:   Vadim Lopatin, coolreader.org@gmail.com
*/
module dlangui.widgets.grid;

import dlangui.widgets.widget;
import dlangui.widgets.controls;
import dlangui.widgets.scroll;
import dlangui.widgets.menu;
import std.conv;
import std.algorithm : equal;

/// cellPopupMenu signal handler interface
interface CellPopupMenuHandler {
    MenuItem getCellPopupMenu(GridWidgetBase source, int col, int row);
}

/**
 * Data provider for GridWidget.
 */
interface GridAdapter {
    /// number of columns
    @property int cols();
    /// number of rows
    @property int rows();
    /// returns widget to draw cell at (col, row)
    Widget cellWidget(int col, int row);
    /// returns row header widget, null if no header
    Widget rowHeader(int row);
    /// returns column header widget, null if no header
    Widget colHeader(int col);
}

/**
 */
class StringGridAdapter : GridAdapter {
    protected int _cols;
    protected int _rows;
    protected dstring[][] _data;
    protected dstring[] _rowTitles;
    protected dstring[] _colTitles;
    /// number of columns
    @property int cols() { return _cols; }
    /// number of columns
    @property void cols(int v) { resize(v, _rows); }
    /// number of rows
    @property int rows() { return _rows; }
    /// number of columns
    @property void rows(int v) { resize(_cols, v); }

    /// returns row header title
    dstring rowTitle(int row) {
        return _rowTitles[row];
    }
    /// set row header title
    StringGridAdapter setRowTitle(int row, dstring title) {
        _rowTitles[row] = title;
        return this;
    }
    /// returns row header title
    dstring colTitle(int col) {
        return _colTitles[col];
    }
    /// set col header title
    StringGridAdapter setColTitle(int col, dstring title) {
        _colTitles[col] = title;
        return this;
    }
    /// get cell text
    dstring cellText(int col, int row) {
        return _data[row][col];
    }
    /// set cell text
    StringGridAdapter setCellText(int col, int row, dstring text) {
        _data[row][col] = text;
        return this;
    }
    /// set new size
    void resize(int cols, int rows) {
        if (cols == _cols && rows == _rows)
            return;
        _cols = cols;
        _rows = rows;
        _data.length = _rows;
        for (int y = 0; y < _rows; y++)
            _data[y].length = _cols;
        _colTitles.length = _cols;
        _rowTitles.length = _rows;
    }
    /// returns widget to draw cell at (col, row)
    Widget cellWidget(int col, int row) { return null; }
    /// returns row header widget, null if no header
    Widget rowHeader(int row) { return null; }
    /// returns column header widget, null if no header
    Widget colHeader(int col) { return null; }
}

/// grid control action codes
enum GridActions : int {
    /// no action
    None = 0,
    /// move selection up
    Up = 2000,
    /// move selection down
    Down,
    /// move selection left
    Left,
    /// move selection right
    Right,

    /// scroll up, w/o changing selection
    ScrollUp,
    /// scroll down, w/o changing selection
    ScrollDown,
    /// scroll left, w/o changing selection
    ScrollLeft,
    /// scroll right, w/o changing selection
    ScrollRight,

    /// scroll up, w/o changing selection
    ScrollPageUp,
    /// scroll down, w/o changing selection
    ScrollPageDown,
    /// scroll left, w/o changing selection
    ScrollPageLeft,
    /// scroll right, w/o changing selection
    ScrollPageRight,

    /// move cursor one page up
    PageUp,
    /// move cursor one page up with selection
    SelectPageUp,
    /// move cursor one page down
    PageDown,
    /// move cursor one page down with selection
    SelectPageDown,
    /// move cursor to the beginning of page
    PageBegin, 
    /// move cursor to the beginning of page with selection
    SelectPageBegin, 
    /// move cursor to the end of page
    PageEnd,   
    /// move cursor to the end of page with selection
    SelectPageEnd,   
    /// move cursor to the beginning of line
    LineBegin,
    /// move cursor to the beginning of line with selection
    SelectLineBegin,
    /// move cursor to the end of line
    LineEnd,
    /// move cursor to the end of line with selection
    SelectLineEnd,
    /// move cursor to the beginning of document
    DocumentBegin,
    /// move cursor to the beginning of document with selection
    SelectDocumentBegin,
    /// move cursor to the end of document
    DocumentEnd,
    /// move cursor to the end of document with selection
    SelectDocumentEnd,
    /// Enter key pressed on cell
    ActivateCell,
}

/// Adapter for custom drawing of some cells in grid widgets
interface CustomGridCellAdapter {
    /// return true for custom drawn cell
    bool isCustomCell(int col, int row);
    /// return cell size
    Point measureCell(int col, int row);
    /// draw data cell content
    void drawCell(DrawBuf buf, Rect rc, int col, int row);
}

interface GridModelAdapter {
    @property int fixedCols();
    @property int fixedRows();
    @property void fixedCols(int value);
    @property void fixedRows(int value);
}

/// Callback for handling of cell selection
interface CellSelectedHandler {
    void onCellSelected(GridWidgetBase source, int col, int row);
}

/// Callback for handling of cell double click or Enter key press
interface CellActivatedHandler {
    void onCellActivated(GridWidgetBase source, int col, int row);
}

/// Callback for handling of view scroll (top left visible cell change)
interface ViewScrolledHandler {
    void onViewScrolled(GridWidgetBase source, int col, int row);
}

/// Abstract grid widget
class GridWidgetBase : ScrollWidgetBase, GridModelAdapter, MenuItemActionHandler {
    /// Callback to handle selection change
    Listener!CellSelectedHandler cellSelected;

    /// Callback to handle cell double click
    Listener!CellActivatedHandler cellActivated;

    /// Callback for handling of view scroll (top left visible cell change)
    Listener!ViewScrolledHandler viewScrolled;

    protected CustomGridCellAdapter _customCellAdapter;

    /// Get adapter to override drawing of some particular cells
    @property CustomGridCellAdapter customCellAdapter() { return _customCellAdapter; }
    /// Set adapter to override drawing of some particular cells
    @property GridWidgetBase customCellAdapter(CustomGridCellAdapter adapter) { _customCellAdapter = adapter; return this; }

    protected GridModelAdapter _gridModelAdapter;
    /// Get adapter to hold grid model data
    @property GridModelAdapter gridModelAdapter() { return _gridModelAdapter; }
    /// Set adapter to hold grid model data
    @property GridWidgetBase gridModelAdapter(GridModelAdapter adapter) { _gridModelAdapter = adapter; return this; }

    protected bool _smoothHScroll = true;
    /// Get smooth horizontal scroll flag - when true - scrolling by pixels, when false - by cells
    @property bool smoothHScroll() { return _smoothHScroll; }
    /// Get smooth horizontal scroll flag - when true - scrolling by pixels, when false - by cells
    @property GridWidgetBase smoothHScroll(bool flgSmoothScroll) { 
        if (_smoothHScroll != flgSmoothScroll) {
            _smoothHScroll = flgSmoothScroll;
            // TODO: snap to grid if necessary
            updateScrollBars();
        }
        return this;
    }

    protected bool _smoothVScroll = true;
    /// Get smooth vertical scroll flag - when true - scrolling by pixels, when false - by cells
    @property bool smoothVScroll() { return _smoothVScroll; }
    /// Get smooth vertical scroll flag - when true - scrolling by pixels, when false - by cells
    @property GridWidgetBase smoothVScroll(bool flgSmoothScroll) { 
        if (_smoothVScroll != flgSmoothScroll) {
            _smoothVScroll = flgSmoothScroll;
            // TODO: snap to grid if necessary
            updateScrollBars();
        }
        return this;
    }

    /// column count (including header columns and fixed columns)
    protected int _cols;
    /// row count (including header rows and fixed rows)
    protected int _rows;
    /// column widths
    protected int[] _colWidths;
    /// total width from first column to right of this
    protected int[] _colCumulativeWidths;
    /// row heights
    protected int[] _rowHeights;
    /// total height from first row to bottom of this
    protected int[] _rowCumulativeHeights;
    /// when true, shows col headers row
    protected bool _showColHeaders;
    /// when true, shows row headers column
    protected bool _showRowHeaders;
    /// number of header rows (e.g. like col name A, B, C... in excel; 0 for no header row)
    protected int _headerRows;
    /// number of header columns (e.g. like row number in excel; 0 for no header column)
    protected int _headerCols;
    /// number of fixed (non-scrollable) columns
    protected int _fixedCols;
    /// number of fixed (non-scrollable) rows
    protected int _fixedRows;

    /// scroll X offset in pixels
    protected int _scrollX;
    /// scroll Y offset in pixels
    protected int _scrollY;

    /// selected cell column
    protected int _col;
    /// selected cell row
    protected int _row;
    /// when true, allows to select only whole row
    protected bool _rowSelect;
    /// default column width - for newly added columns
    protected int _defColumnWidth;
    /// default row height - for newly added rows
    protected int _defRowHeight;

    // properties

    /// selected column
    @property int col() { return _col - _headerCols; }
    /// selected row
    @property int row() { return _row - _headerRows; }
    /// column count
    @property int cols() { return _cols - _headerCols; }
    /// set column count
    @property GridWidgetBase cols(int c) { resize(c, rows); return this; }
    /// row count
    @property int rows() { return _rows - _headerRows; }
    /// set row count
    @property GridWidgetBase rows(int r) { resize(cols, r); return this; }

    protected bool _allowColResizing = true;
    /// get col resizing flag; when true, allow resizing of column with mouse
    @property bool allowColResizing() { return _allowColResizing; }
    /// set col resizing flag; when true, allow resizing of column with mouse
    @property GridWidgetBase allowColResizing(bool flgAllowColResizing) { _allowColResizing = flgAllowColResizing; return this; }

    protected uint _selectionColor = 0x804040FF;
    protected uint _selectionColorRowSelect = 0xC0A0B0FF;
    protected uint _fixedCellBackgroundColor = 0xC0E0E0E0;
    protected uint _fixedCellBorderColor = 0xC0C0C0C0;
    protected uint _cellBorderColor = 0xC0C0C0C0;
    protected uint _cellHeaderBorderColor = 0xC0202020;
    protected uint _cellHeaderBackgroundColor = 0xC0909090;
    protected uint _cellHeaderSelectedBackgroundColor = 0x80FFC040;

    /// row header column count
    @property int headerCols() { return _headerCols; }
    @property GridWidgetBase headerCols(int c) { 
        _headerCols = c; 
        invalidate(); 
        return this; 
    }
    /// col header row count
    @property int headerRows() { return _headerRows; }
    @property GridWidgetBase headerRows(int r) { 
        _headerRows = r; 
        invalidate(); 
        return this; 
    }

    /// fixed (non-scrollable) data column count
    @property int fixedCols() { return _gridModelAdapter is null ? _fixedCols : _gridModelAdapter.fixedCols; }
    @property void fixedCols(int c) { 
        if (_gridModelAdapter is null)
            _fixedCols = c;
        else
            _gridModelAdapter.fixedCols = c;
        invalidate(); 
    }
    /// fixed (non-scrollable) data row count
    @property int fixedRows() { return _gridModelAdapter is null ? _fixedRows : _gridModelAdapter.fixedCols; }
    @property void fixedRows(int r) {
        if (_gridModelAdapter is null)
            _fixedRows = r; 
        else
            _gridModelAdapter.fixedCols = r;
        invalidate(); 
    }

    /// default column width - for newly added columns
    @property int defColumnWidth() {
        return _defColumnWidth;
    }
    @property GridWidgetBase defColumnWidth(int v) {
        _defColumnWidth = v;
        return this;
    }
    /// default row height - for newly added rows
    @property int defRowHeight() {
        return _defRowHeight;
    }
    @property GridWidgetBase defRowHeight(int v) {
        _defRowHeight = v;
        return this;
    }

    /// when true, allows only select the whole row
    @property bool rowSelect() {
        return _rowSelect;
    }
    @property GridWidgetBase rowSelect(bool flg) {
        _rowSelect = flg;
        invalidate();
        return this;
    }

    /// set bool property value, for ML loaders
    mixin(generatePropertySettersMethodOverride("setBoolProperty", "bool",
          "showColHeaders", "showColHeaders", "rowSelect", "smoothHScroll", "smoothVScroll", "allowColResizing"));

    /// set int property value, for ML loaders
    mixin(generatePropertySettersMethodOverride("setIntProperty", "int",
          "headerCols", "headerRows", "fixedCols", "fixedRows", "cols", "rows", "defColumnWidth", "defRowHeight"));

    /// flag to enable column headers
    @property bool showColHeaders() {
        return _showColHeaders;
    }

    @property GridWidgetBase showColHeaders(bool show) {
        if (_showColHeaders != show) {
            _showColHeaders = show;
            for (int i = 0; i < _headerRows; i++)
                autoFitRowHeight(i);
            invalidate();
        }
        return this;
    }

    /// flag to enable row headers
    @property bool showRowHeaders() {
        return _showRowHeaders;
    }

    @property GridWidgetBase showRowHeaders(bool show) {
        if (_showRowHeaders != show) {
            _showRowHeaders = show;
            for (int i = 0; i < _headerCols; i++)
                autoFitColumnWidth(i);
            invalidate();
        }
        return this;
    }

    /// recalculate colCumulativeWidths, rowCumulativeHeights after resizes
    protected void updateCumulativeSizes() {
        _colCumulativeWidths.length = _colWidths.length;
        _rowCumulativeHeights.length = _rowHeights.length;
        for (int i = 0; i < _colCumulativeWidths.length; i++) {
            if (i == 0)
                _colCumulativeWidths[i] = _colWidths[i];
            else
                _colCumulativeWidths[i] = _colWidths[i] + _colCumulativeWidths[i - 1];
        }
        for (int i = 0; i < _rowCumulativeHeights.length; i++) {
            if (i == 0)
                _rowCumulativeHeights[i] = _rowHeights[i];
            else
                _rowCumulativeHeights[i] = _rowHeights[i] + _rowCumulativeHeights[i - 1];
        }
    }

    /// set new size
    void resize(int c, int r) {
        if (c == cols && r == rows)
            return;
        _colWidths.length = c + _headerCols;
        for (int i = _cols; i < c + _headerCols; i++) {
            _colWidths[i] = _defColumnWidth;
        }
        _rowHeights.length = r + _headerRows;
        for (int i = _rows; i < r + _headerRows; i++) {
            _rowHeights[i] = _defRowHeight;
        }
        _cols = c + _headerCols;
        _rows = r + _headerRows;
        updateCumulativeSizes();
    }

    /// count of non-scrollable columns (header + fixed)
    @property int nonScrollCols() { return _headerCols + fixedCols; }
    /// count of non-scrollable rows (header + fixed)
    @property int nonScrollRows() { return _headerRows + fixedRows; }
    /// return all (fixed + scrollable) cells size in pixels
    @property Point fullAreaPixels() {
        return Point(_cols ? _colCumulativeWidths[_cols - 1] : 0, _rows ? _rowCumulativeHeights[_rows - 1] : 0);
    }
    /// non-scrollable area size in pixels
    @property Point nonScrollAreaPixels() {
        int nscols = nonScrollCols;
        int nsrows = nonScrollRows;
        return Point(nscols ? _colCumulativeWidths[nscols - 1] : 0, nsrows ? _rowCumulativeHeights[nsrows - 1] : 0);
    }
    /// scrollable area size in pixels
    @property Point scrollAreaPixels() {
        return fullAreaPixels - nonScrollAreaPixels;
    }
    /// get cell rectangle (relative to client area) not counting scroll position
    Rect cellRectNoScroll(int x, int y) {
        if (x < 0 || y < 0 || x >= _cols || y >= _rows)
            return Rect(0,0,0,0);
        return Rect(x ? _colCumulativeWidths[x - 1] : 0, y ? _rowCumulativeHeights[y - 1] : 0,
                _colCumulativeWidths[x], _rowCumulativeHeights[y]);
    }
    /// get cell rectangle moved by scroll pixels (may overlap non-scroll cols!)
    Rect cellRectScroll(int x, int y) {
        Rect rc = cellRectNoScroll(x, y);
        int nscols = nonScrollCols;
        int nsrows = nonScrollRows;
        if (x >= nscols) {
            rc.left -= _scrollX;
            rc.right -= _scrollX;
        }
        if (y >= nsrows) {
            rc.top -= _scrollY;
            rc.bottom -= _scrollY;
        }
        return rc;
    }
    /// returns true if column is inside client area and not overlapped outside scroll area
    bool colVisible(int x) {
        if (x < 0 || x >= _cols)
            return false;
        if (x == 0)
            return true;
        int nscols = nonScrollCols;
        if (x < nscols) {
            // non-scrollable
            return _colCumulativeWidths[x - 1] < _clientRect.width;
        } else {
            // scrollable
            int start = _colCumulativeWidths[x - 1] - _scrollX;
            int end = _colCumulativeWidths[x] - _scrollX;
            if (start >= _clientRect.width)
                return false; // at right
            if (end <= (nscols ? _colCumulativeWidths[nscols - 1] : 0))
                return false; // at left
            return true; // visible
        }
    }
    /// returns true if row is inside client area and not overlapped outside scroll area
    bool rowVisible(int y) {
        if (y < 0 || y >= _rows)
            return false;
        if (y == 0)
            return true; // first row always visible
        int nsrows = nonScrollRows;
        if (y < nsrows) {
            // non-scrollable
            return _rowCumulativeHeights[y - 1] < _clientRect.height;
        } else {
            // scrollable
            int start = _rowCumulativeHeights[y - 1] - _scrollY;
            int end = _rowCumulativeHeights[y] - _scrollY;
            if (start >= _clientRect.height)
                return false; // at right
            if (end <= (nsrows ? _rowCumulativeHeights[nsrows - 1] : 0))
                return false; // at left
            return true; // visible
        }
    }

    void setColWidth(int x, int w) {
        _colWidths[x] = w;
        updateCumulativeSizes();
    }

    void setRowHeight(int y, int w) {
        _rowHeights[y] = w;
        updateCumulativeSizes();
    }

    /// get column width, 0 is header column
    int colWidth(int col) {
        if (col < 0 || col >= _colWidths.length)
            return 0;
        return _colWidths[col];
    }

    /// get row height, 0 is header row
    int rowHeight(int row) {
        if (row < 0 || row >= _rowHeights.length)
            return 0;
        return _rowHeights[row];
    }

    /// returns cell rectangle relative to client area; row 0 is col headers row; col 0 is row headers column
    Rect cellRect(int x, int y) {
        return cellRectScroll(x, y);
    }

    /// converts client rect relative coordinates to cell coordinates
    bool pointToCell(int x, int y, ref int col, ref int row, ref Rect cellRect) {
        int nscols = nonScrollCols;
        int nsrows = nonScrollRows;
        Point ns = nonScrollAreaPixels;
        col = colByAbsoluteX(x < ns.x ? x : x + _scrollX);
        row = rowByAbsoluteY(y < ns.y ? y : y + _scrollY);
        cellRect = cellRectScroll(col, row);
        return cellRect.isPointInside(x, y);
    }

    /// update scrollbar positions
    override protected void updateScrollBars() {
        calcScrollableAreaPos();
        correctScrollPos();
        super.updateScrollBars();
    }

    /// search for index of position inside cumulative sizes array
    protected static int findPosIndex(int[] cumulativeSizes, int pos) {
        // binary search
        if (pos < 0 || !cumulativeSizes.length)
            return 0;
        int a = 0; // inclusive lower bound
        int b = cast(int)cumulativeSizes.length; // exclusive upper bound
        if (pos >= cumulativeSizes[$ - 1])
            return b - 1;
        int * w = cumulativeSizes.ptr;
        for(;;) {
            if (a + 1 >= b)
                return a; // single point
            // middle point
            // always inside range
            int c = (a + b) >> 1;
            int start = c ? w[c - 1] : 0;
            int end = w[c];
            if (pos < start) {
                // left
                b = c;
            } else if (pos >= end) {
                // right
                a = c + 1;
            } else {
                // found
                return c;
            }
        }
    }

    /// column by X, ignoring scroll position
    protected int colByAbsoluteX(int x) {
        return findPosIndex(_colCumulativeWidths, x);
    }

    /// row by Y, ignoring scroll position
    protected int rowByAbsoluteY(int y) {
        return findPosIndex(_rowCumulativeHeights, y);
    }

    /// returns first fully visible column in scroll area
    protected int scrollCol() {
        int x = nonScrollAreaPixels.x + _scrollX;
        int col = colByAbsoluteX(x);
        int start = col ? _colCumulativeWidths[col - 1] : 0;
        int end = _colCumulativeWidths[col];
        if (x <= start)
            return col;
        // align to next col
        return colByAbsoluteX(end);
    }

    /// returns last fully visible column in scroll area
    protected int lastScrollCol() {
        int x = nonScrollAreaPixels.x + _scrollX + _visibleScrollableArea.width - 1;
        int col = colByAbsoluteX(x);
        int start = col ? _colCumulativeWidths[col - 1] : 0;
        int end = _colCumulativeWidths[col];
        if (x >= end - 1) // fully visible
            return col;
        if (col > nonScrollCols && col > scrollCol)
            col--;
        return col;
    }

    /// returns first fully visible row in scroll area
    protected int scrollRow() {
        int y = nonScrollAreaPixels.y + _scrollY;
        int row = rowByAbsoluteY(y);
        int start = row ? _rowCumulativeHeights[row - 1] : 0;
        int end = _rowCumulativeHeights[row];
        if (y <= start)
            return row;
        // align to next col
        return rowByAbsoluteY(end);
    }

    /// returns last fully visible row in scroll area
    protected int lastScrollRow() {
        int y = nonScrollAreaPixels.y + _scrollY + _visibleScrollableArea.height - 1;
        int row = rowByAbsoluteY(y);
        int start = row ? _rowCumulativeHeights[row - 1] : 0;
        int end = _rowCumulativeHeights[row];
        if (y >= end - 1) // fully visible
            return row;
        if (row > nonScrollRows && row > scrollRow)
            row--;
        return row;
    }

    /// move scroll position horizontally by dx, and vertically by dy; returns true if scrolled
    bool scrollBy(int dx, int dy) {
        int col = scrollCol + dx;
        int row = scrollRow + dy;
        if (col >= _cols)
            col = _cols - 1;
        if (row >= _rows)
            row = _rows - 1;
        if (col < nonScrollCols)
            col = nonScrollCols;
        if (row < nonScrollCols)
            row = nonScrollRows;
        Rect rc = cellRectNoScroll(col, row);
        Point ns = nonScrollAreaPixels;
        return scrollTo(rc.left - ns.x, rc.top - ns.y);
    }

    /// override to support modification of client rect after change, e.g. apply offset
    override protected void handleClientRectLayout(ref Rect rc) {
        //correctScrollPos();
    }

    // ensure scroll position is inside min/max area
    protected void correctScrollPos() {
        int maxscrollx = _fullScrollableArea.width - _visibleScrollableArea.width;
        int maxscrolly = _fullScrollableArea.height - _visibleScrollableArea.height;
        if (_scrollX < 0)
            _scrollX = 0;
        if (_scrollY < 0)
            _scrollY = 0;
        if (_scrollX > maxscrollx)
            _scrollX = maxscrollx;
        if (_scrollY > maxscrolly)
            _scrollY = maxscrolly;
    }

    /// set scroll position to show specified cell as top left in scrollable area; col or row -1 value means no change
    bool scrollTo(int x, int y, GridWidgetBase source = null, bool doNotify = true) {
        int oldx = _scrollX;
        int oldy = _scrollY;
        _scrollX = x;
        _scrollY = y;
        correctScrollPos();
        updateScrollBars();
        invalidate();
        bool changed = oldx != _scrollX || oldy != _scrollY;
        if (doNotify && changed && viewScrolled.assigned) {
            if (source is null)
                source = this;
            viewScrolled(source, x, y);
        }
        return changed;
    }

    /// process horizontal scrollbar event
    override bool onHScroll(ScrollEvent event) {
        if (event.action == ScrollAction.SliderMoved || event.action == ScrollAction.SliderReleased) {
            scrollTo(event.position, _scrollY);
        } else if (event.action == ScrollAction.PageUp) {
            dispatchAction(new Action(GridActions.ScrollPageLeft));
        } else if (event.action == ScrollAction.PageDown) {
            dispatchAction(new Action(GridActions.ScrollPageRight));
        } else if (event.action == ScrollAction.LineUp) {
            dispatchAction(new Action(GridActions.ScrollLeft));
        } else if (event.action == ScrollAction.LineDown) {
            dispatchAction(new Action(GridActions.ScrollRight));
        }
        return true;
    }

    /// process vertical scrollbar event
    override bool onVScroll(ScrollEvent event) {
        if (event.action == ScrollAction.SliderMoved || event.action == ScrollAction.SliderReleased) {
            scrollTo(_scrollX, event.position);
        } else if (event.action == ScrollAction.PageUp) {
            dispatchAction(new Action(GridActions.ScrollPageUp));
        } else if (event.action == ScrollAction.PageDown) {
            dispatchAction(new Action(GridActions.ScrollPageDown));
        } else if (event.action == ScrollAction.LineUp) {
            dispatchAction(new Action(GridActions.ScrollUp));
        } else if (event.action == ScrollAction.LineDown) {
            dispatchAction(new Action(GridActions.ScrollDown));
        }
        return true;
    }

    /// ensure that cell is visible (scroll if necessary)
    void makeCellVisible(int col, int row) {
        bool scrolled = false;
        int newx = _scrollX;
        int newy = _scrollY;
        Rect rc = cellRectNoScroll(col, row);
        Rect visibleRc = _visibleScrollableArea;
        if (col >= nonScrollCols) {
            // can scroll X
            if (rc.left < visibleRc.left) {
                // scroll left
                newx += rc.left - visibleRc.left;
            } else if (rc.right > visibleRc.right) {
                // scroll right
                newx += rc.right - visibleRc.right;
            }
        }
        if (row >= nonScrollRows) {
            // can scroll Y
            if (rc.top < visibleRc.top) {
                // scroll left
                newy += rc.top - visibleRc.top;
            } else if (rc.bottom > visibleRc.bottom) {
                // scroll right
                newy += rc.bottom - visibleRc.bottom;
            }
        }
        if (newy < 0)
            newy = 0;
        if (newx < 0)
            newx = 0;
        if (newx != _scrollX || newy != _scrollY) {
            scrollTo(newx, newy);
        }
    }

    /// move selection to specified cell
    bool selectCell(int col, int row, bool makeVisible = true, GridWidgetBase source = null, bool needNotification = true) {
        if (source is null)
            source = this;
        if (_col == col && _row == row)
            return false; // same position
        if (col < _headerCols || row < _headerRows || col >= _cols || row >= _rows)
            return false; // out of range
        _col = col;
        _row = row;
        invalidate();
        calcScrollableAreaPos();
        if (makeVisible)
            makeCellVisible(_col, _row);
        if (needNotification && cellSelected.assigned)
            cellSelected(source, _col - _headerCols, _row - _headerRows);
        return true;
    }

    /// Select cell and call onCellActivated handler
    bool activateCell(int col, int row) {
        if (_col != col || _row != row) {
            selectCell(col, row, true);
        }
        if (cellActivated.assigned)
            cellActivated(this, this.col, this.row);
        return true;
    }

    /// cell popup menu
    Signal!CellPopupMenuHandler cellPopupMenu;
    /// popup menu item action
    Signal!MenuItemActionHandler menuItemAction;

    protected MenuItem getCellPopupMenu(int col, int row) {
        if (cellPopupMenu.assigned)
            return cellPopupMenu(this, col, row);
        return null;
    }

    /// handle popup menu action
    protected bool onMenuItemAction(const Action action) {
        if (menuItemAction.assigned)
            return menuItemAction(action);
        return false;
    }

    /// returns true if widget can show popup menu (e.g. by mouse right click at point x,y)
    override bool canShowPopupMenu(int x, int y) {
        int col, row;
        Rect rc;
        x -= _clientRect.left;
        y -= _clientRect.top;
        pointToCell(x, y, col, row, rc);
        MenuItem item = getCellPopupMenu(col - _headerCols, row - _headerRows);
        if (!item)
            return false;
        return true;
    }

    /// shows popup menu at (x,y)
    override void showPopupMenu(int xx, int yy) {
        int col, row;
        Rect rc;
        int x = xx - _clientRect.left;
        int y = yy - _clientRect.top;
        pointToCell(x, y, col, row, rc);
        MenuItem menu = getCellPopupMenu(col - _headerCols, row - _headerRows);
        if (menu) {
            import dlangui.widgets.popup;
            menu.updateActionState(this);
            PopupMenu popupMenu = new PopupMenu(menu);
            popupMenu.menuItemAction = this;
            PopupWidget popup = window.showPopup(popupMenu, this, PopupAlign.Point | PopupAlign.Right, xx, yy);
            popup.flags = PopupFlags.CloseOnClickOutside;
        }
    }

    /// returns mouse cursor type for widget
    override uint getCursorType(int x, int y) {
        if (_allowColResizing) {
            if (_colResizingIndex >= 0) // resizing in progress
                return CursorType.SizeWE;
            int col = isColumnResizingPoint(x, y);
            if (col >= 0)
                return CursorType.SizeWE;
        }
        return CursorType.Arrow;
    }

    protected int _colResizingIndex = -1;
    protected int _colResizingStartX = -1;
    protected int _colResizingStartWidth = -1;

    protected void startColResize(int col, int x) {
        _colResizingIndex = col;
        _colResizingStartX = x;
        _colResizingStartWidth = _colWidths[col];
    }
    protected void processColResize(int x) {
        if (_colResizingIndex < 0 || _colResizingIndex >= _cols)
            return;
        int newWidth = _colResizingStartWidth + x - _colResizingStartX;
        if (newWidth < 0)
            newWidth = 0;
        _colWidths[_colResizingIndex] = newWidth;
        updateCumulativeSizes();
        updateScrollBars();
        invalidate();
    }
    protected void endColResize() {
        _colResizingIndex = -1;
    }

    /// return column index to resize if point is in column resize area in header row, -1 if outside resize area
    int isColumnResizingPoint(int x, int y) {
        x -= _clientRect.left;
        y -= _clientRect.top;
        if (!_headerRows)
            return -1; // no header rows
        if (y >= _rowCumulativeHeights[_headerRows - 1])
            return -1; // not in header row
        // point is somewhere in header row
        int resizeRange = BACKEND_GUI ? 4.pointsToPixels : 1;
        if (x >= nonScrollAreaPixels.x)
            x += _scrollX;
        int col = colByAbsoluteX(x);
        int start = col > 0 ? _colCumulativeWidths[col - 1] : 0;
        int end = col < _cols ? _colCumulativeWidths[col] : _colCumulativeWidths[$ - 1];
        if (x >= end - resizeRange / 2)
            return col; // resize this column
        if (x <= start + resizeRange / 2)
            return col - 1; // resize previous column
        return -1;
    }

    /// handle mouse wheel events
    override bool onMouseEvent(MouseEvent event) {
        if (visibility != Visibility.Visible)
            return false;
        int c, r; // col, row
        Rect rc;
        bool cellFound = false;
        bool normalCell = false;
        bool insideHeaderRow = false;
        bool insideHeaderCol = false;
        if (_colResizingIndex >= 0) { 
            if (event.action == MouseAction.Move) {
                // column resize is active
                processColResize(event.x);
                return true;
            }
            if (event.action == MouseAction.ButtonUp || event.action == MouseAction.Cancel) {
                // stop column resizing
                if (event.action == MouseAction.ButtonUp)
                    processColResize(event.x);
                endColResize();
                return true;
            }
        }
        // convert coordinates
        if (event.action == MouseAction.ButtonUp || event.action == MouseAction.ButtonDown || event.action == MouseAction.Move) {
            int x = event.x;
            int y = event.y;
            x -= _clientRect.left;
            y -= _clientRect.top;
            if (_headerRows)
                insideHeaderRow = y < _rowCumulativeHeights[_headerRows - 1];
            if (_headerCols)
                insideHeaderCol = y < _colCumulativeWidths[_headerCols - 1];
            cellFound = pointToCell(x, y, c, r, rc);
            normalCell = c >= _headerCols && r >= _headerRows;
        }
        if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left) {
            if (canFocus && !focused)
                setFocus();
            int resizeCol = isColumnResizingPoint(event.x, event.y);
            if (resizeCol >= 0) {
                // start column resizing
                startColResize(resizeCol, event.x);
                event.track(this);
                return true;
            }
            if (cellFound && normalCell) {
                if (c == _col && r == _row && event.doubleClick) {
                    activateCell(c, r);
                } else {
                    selectCell(c, r);
                }
            }
            return true;
        }
        if (event.action == MouseAction.Move && (event.flags & MouseFlag.LButton)) {
            // TODO: selection
            if (cellFound && normalCell) {
                selectCell(c, r);
            }
            return true;
        }
        if (event.action == MouseAction.Wheel) {
            if (event.flags & MouseFlag.Shift)
                scrollBy(-event.wheelDelta, 0);
            else
                scrollBy(0, -event.wheelDelta);
            return true;
        }
        return super.onMouseEvent(event);
    }


    /// calculate scrollable area info
    protected void calcScrollableAreaPos() {
        if (_scrollX < 0)
            _scrollX = 0;
        if (_scrollY < 0)
            _scrollY = 0;
        // calculate _fullScrollableArea, _visibleScrollableArea relative to clientRect
        Point nonscrollPixels = nonScrollAreaPixels;
        Point scrollPixels = scrollAreaPixels;
        Point fullPixels = fullAreaPixels;
        Point clientPixels = _clientRect.size;
        Point scrollableClient = clientPixels - nonscrollPixels;
        if (scrollableClient.x < 0)
            scrollableClient.x = 0;
        if (scrollableClient.y < 0)
            scrollableClient.y = 0;
        _fullScrollableArea = Rect(nonscrollPixels.x, nonscrollPixels.y, fullPixels.x, fullPixels.y);
        if (_fullScrollableArea.right < clientPixels.x)
            _fullScrollableArea.right = clientPixels.x;
        if (_fullScrollableArea.bottom < clientPixels.y)
            _fullScrollableArea.bottom = clientPixels.y;

        // extending scroll area if necessary
        int maxscrollx = _fullScrollableArea.right - scrollableClient.x;
        int col = colByAbsoluteX(maxscrollx);
        int maxscrolly = _fullScrollableArea.bottom - scrollableClient.y;
        int row = rowByAbsoluteY(maxscrolly);
        Rect rc = cellRectNoScroll(col, row);

        // extend scroll area to show full column at left when scrolled to rightmost column
        if (maxscrollx >= nonscrollPixels.x && rc.left < maxscrollx) {
            _fullScrollableArea.right += rc.right - maxscrollx;
        }

        // extend scroll area to show full row at top when scrolled to end row
        if (maxscrolly >= nonscrollPixels.y && rc.top < maxscrolly) {
            _fullScrollableArea.bottom += rc.bottom - maxscrolly;
        }

        // scrollable area
        Point scrollableClientAreaSize = scrollableClient; // size left for scrollable area
        int scrollx = nonscrollPixels.x + _scrollX;
        int scrolly = nonscrollPixels.y + _scrollY;
        _visibleScrollableArea = Rect(scrollx, scrolly, scrollx + scrollableClientAreaSize.x, scrolly + scrollableClientAreaSize.y);
    }

    protected int _maxScrollCol;
    protected int _maxScrollRow;

    override protected bool handleAction(const Action a) {
        calcScrollableAreaPos();
        int actionId = a.id;
        if (_rowSelect) {
            switch(actionId) with(GridActions)
            {
                case Left:
                    actionId = GridActions.ScrollLeft;
                    break;
                case Right:
                    actionId = GridActions.ScrollRight;
                    break;
                //case LineBegin:
                //    actionId = GridActions.ScrollPageLeft;
                //    break;
                //case LineEnd:
                //    actionId = GridActions.ScrollPageRight;
                //    break;
                default:
                    break;
            }
        }

        int sc = scrollCol; // first fully visible column in scroll area
        int sr = scrollRow; // first fully visible row in scroll area
        switch (actionId) with(GridActions)
        {
            case ActivateCell:
                if (cellActivated.assigned) {
                    cellActivated(this, col, row);
                    return true;
                }
                return false;
            case ScrollLeft:
                scrollBy(-1, 0);
                return true;
            case Left:
                selectCell(_col - 1, _row);
                return true;
            case ScrollRight:
                scrollBy(1, 0);
                return true;
            case Right:
                selectCell(_col + 1, _row);
                return true;
            case ScrollUp:
                scrollBy(0, -1);
                return true;
            case Up:
                selectCell(_col, _row - 1);
                return true;
            case ScrollDown:
                if (lastScrollRow < _rows - 1)
                    scrollBy(0, 1);
                return true;
            case Down:
                selectCell(_col, _row + 1);
                return true;
            case ScrollPageLeft:
                // scroll left cell by cell
                while (scrollCol > nonScrollCols) {
                    scrollBy(-1, 0);
                    if (lastScrollCol <= sc)
                        break;
                }
                return true;
            case ScrollPageRight:
                int prevCol = lastScrollCol;
                while (scrollCol < prevCol) {
                    if (!scrollBy(1, 0))
                        break;
                }
                return true;
            case ScrollPageUp:
                // scroll up line by line
                while (scrollRow > nonScrollRows) {
                    scrollBy(0, -1);
                    if (lastScrollRow <= sr)
                        break;
                }
                return true;
            case ScrollPageDown:
                int prevRow = lastScrollRow;
                while (scrollRow < prevRow) {
                    if (!scrollBy(0, 1))
                        break;
                }
                return true;
            case LineBegin:
                if (sc > nonScrollCols && _col > sc && !_rowSelect) {
                    // move selection and don's scroll
                    selectCell(sc, _row);
                } else {
                    // scroll
                    if (sc > nonScrollCols) {
                        _scrollX = 0;
                        updateScrollBars();
                        invalidate();
                    }
                    selectCell(_headerCols, _row);
                }
                return true;
            case LineEnd:
                if (_col < lastScrollCol && !_rowSelect) {
                    // move selection and don's scroll
                    selectCell(lastScrollCol, _row);
                } else {
                    selectCell(_cols - 1, _row);
                }
                return true;
            case DocumentBegin:
                if (_scrollY > 0) {
                    _scrollY = 0;
                    updateScrollBars();
                    invalidate();
                }
                selectCell(_col, _headerRows);
                return true;
            case DocumentEnd:
                selectCell(_col, _rows - 1);
                return true;
            case PageBegin:
                if (scrollRow > nonScrollRows)
                    selectCell(_col, scrollRow);
                else
                    selectCell(_col, _headerRows);
                return true;
            case PageEnd:
                selectCell(_col, lastScrollRow);
                return true;
            case PageUp:
                if (_row > sr) {
                    // not at top scrollable cell
                    selectCell(_col, sr);
                } else {
                    // at top of scrollable area
                    if (scrollRow > nonScrollRows) {
                        // scroll up line by line
                        int prevRow = _row;
                        for (int i = prevRow - 1; i >= _headerRows; i--) {
                            selectCell(_col, i);
                            if (lastScrollRow <= prevRow)
                                break;
                        }
                    } else {
                        // scrolled to top - move upper cell
                        selectCell(_col, _headerRows);
                    }
                }
                return true;
            case PageDown:
                if (_row < _rows - 1) {
                    int lr = lastScrollRow;
                    if (_row < lr) {
                        // not at bottom scrollable cell
                        selectCell(_col, lr);
                    } else {
                        // scroll down
                        int prevRow = _row;
                        for (int i = prevRow + 1; i < _rows; i++) {
                            selectCell(_col, i);
                            calcScrollableAreaPos();
                            if (scrollRow >= prevRow)
                                break;
                        }
                    }
                }
                return true;
            default:
                return super.handleAction(a);
        }
    }

    /// calculate full content size in pixels
    override Point fullContentSize() {
        Point sz;
        for (int i = 0; i < _cols; i++)
            sz.x += _colWidths[i];
        for (int i = 0; i < _rows; i++)
            sz.y += _rowHeights[i];
        return sz;
    }

    override protected void drawClient(DrawBuf buf) {
        if (!_cols || !_rows)
            return; // no cells
        auto saver = ClipRectSaver(buf, _clientRect, 0);

        int nscols = nonScrollCols;
        int nsrows = nonScrollRows;
        Point nspixels = nonScrollAreaPixels;
        int maxVisibleCol = colByAbsoluteX(_clientRect.width + _scrollX);
        int maxVisibleRow = rowByAbsoluteY(_clientRect.height + _scrollY);
        for (int phase = 0; phase < 2; phase++) { // phase0 == background, phase1 == foreground
            for (int y = 0; y <= maxVisibleRow; y++) {
                if (!rowVisible(y))
                    continue;
                for (int x = 0; x <= maxVisibleCol; x++) {
                    if (!colVisible(x))
                        continue;
                    Rect cellRect = cellRectScroll(x, y);
                    Rect clippedCellRect = cellRect;
                    if (x >= nscols && cellRect.left < nspixels.x)
                        clippedCellRect.left = nspixels.x; // clip scrolled left
                    if (y >= nsrows && cellRect.top < nspixels.y)
                        clippedCellRect.top = nspixels.y; // clip scrolled left
                    if (clippedCellRect.empty)
                        continue; // completely clipped out

                    cellRect.moveBy(_clientRect.left, _clientRect.top);
                    clippedCellRect.moveBy(_clientRect.left, _clientRect.top);

                    auto cellSaver = ClipRectSaver(buf, clippedCellRect, 0);
                    bool isHeader = x < _headerCols || y < _headerRows;
                    if (phase == 0) {
                        if (isHeader)
                            drawHeaderCellBackground(buf, cellRect, x - _headerCols, y - _headerRows);
                        else
                            drawCellBackground(buf, cellRect, x - _headerCols, y - _headerRows);
                    } else {
                        if (isHeader)
                            drawHeaderCell(buf, cellRect, x - _headerCols, y - _headerRows);
                        else
                            drawCell(buf, cellRect, x - _headerCols, y - _headerRows);
                    }
                }
            }
        }
    }

    /// draw data cell content
    protected void drawCell(DrawBuf buf, Rect rc, int col, int row) {
        // override it
    }

    /// draw header cell content
    protected void drawHeaderCell(DrawBuf buf, Rect rc, int col, int row) {
        // override it
    }

    /// draw data cell background
    protected void drawCellBackground(DrawBuf buf, Rect rc, int col, int row) {
        // override it
    }

    /// draw header cell background
    protected void drawHeaderCellBackground(DrawBuf buf, Rect rc, int col, int row) {
        // override it
    }

    protected Point measureCell(int x, int y) {
        // override it!
        return Point(BACKEND_CONSOLE ? 5 : 80, BACKEND_CONSOLE ? 1 : 20);
    }

    protected int measureColWidth(int x) {
        int m = 0;
        for (int i = 0; i < _rows; i++) {
            Point sz = measureCell(x - _headerCols, i - _headerRows);
            if (m < sz.x)
                m = sz.x;
        }
        static if (BACKEND_GUI) {
            if (m < 10)
                m = 10; // TODO: use min size
        }
        return m;
    }

    protected int measureRowHeight(int y) {
        int m = 0;
        for (int i = 0; i < _cols; i++) {
            Point sz = measureCell(i - _headerCols, y - _headerRows);
            if (m < sz.y)
                m = sz.y;
        }
        static if (BACKEND_GUI) {
            if (m < 12)
                m = 12; // TODO: use min size
        }
        return m;
    }

    void autoFitColumnWidth(int i) {
        _colWidths[i] = (i < _headerCols && !_showRowHeaders) ? 0 : measureColWidth(i) + (BACKEND_CONSOLE ? 1 : 3.pointsToPixels);
    }

    /// extend specified column width to fit client area if grid width
    void fillColumnWidth(int colIndex) {
        int w = _clientRect.width;
        int totalw = 0;
        for (int i = 0; i < _cols; i++)
            totalw += _colWidths[i];
        if (w > totalw)
            _colWidths[colIndex + _headerCols] += w - totalw;
        invalidate();
    }

    void autoFitColumnWidths() {
        for (int i = 0; i < _cols; i++)
            autoFitColumnWidth(i);
        invalidate();
    }

    void autoFitRowHeight(int i) {
        _rowHeights[i] = (i < _headerRows && !_showColHeaders) ? 0 : measureRowHeight(i) + (BACKEND_CONSOLE ? 0 : 2);
    }

    void autoFitRowHeights() {
        for (int i = 0; i < _rows; i++)
            autoFitRowHeight(i);
    }

    void autoFit() {
        autoFitColumnWidths();
        autoFitRowHeights();
    }

    this(string ID = null, ScrollBarMode hscrollbarMode = ScrollBarMode.Visible, ScrollBarMode vscrollbarMode = ScrollBarMode.Visible) {
        super(ID, hscrollbarMode, vscrollbarMode);
        _headerCols = 1;
        _headerRows = 1;
        _defRowHeight = BACKEND_CONSOLE ? 1 : pointsToPixels(16);
        _defColumnWidth = BACKEND_CONSOLE ? 5 : 100;

        _showColHeaders = true;
        _showRowHeaders = true;
        acceleratorMap.add( [
            new Action(GridActions.Up, KeyCode.UP, 0),
            new Action(GridActions.Down, KeyCode.DOWN, 0),
            new Action(GridActions.Left, KeyCode.LEFT, 0),
            new Action(GridActions.Right, KeyCode.RIGHT, 0),
            new Action(GridActions.LineBegin, KeyCode.HOME, 0),
            new Action(GridActions.LineEnd, KeyCode.END, 0),
            new Action(GridActions.PageUp, KeyCode.PAGEUP, 0),
            new Action(GridActions.PageDown, KeyCode.PAGEDOWN, 0),
            new Action(GridActions.PageBegin, KeyCode.PAGEUP, KeyFlag.Control),
            new Action(GridActions.PageEnd, KeyCode.PAGEDOWN, KeyFlag.Control),
            new Action(GridActions.DocumentBegin, KeyCode.HOME, KeyFlag.Control),
            new Action(GridActions.DocumentEnd, KeyCode.END, KeyFlag.Control),
            new Action(GridActions.ActivateCell, KeyCode.RETURN, 0),
        ]);
        focusable = true;
    }
}

class StringGridWidgetBase : GridWidgetBase {
    this(string ID = null) {
        super(ID);
    }
    /// get cell text
    abstract dstring cellText(int col, int row);
    /// set cell text
    abstract StringGridWidgetBase setCellText(int col, int row, dstring text);
    /// returns row header title
    abstract dstring rowTitle(int row);
    /// set row header title
    abstract StringGridWidgetBase setRowTitle(int row, dstring title);
    /// returns row header title
    abstract dstring colTitle(int col);
    /// set col header title
    abstract StringGridWidgetBase setColTitle(int col, dstring title);

    ///// selected column
    //@property override int col() { return _col - _headerCols; }
    ///// selected row
    //@property override int row() { return _row - _headerRows; }
    ///// column count
    //@property override int cols() { return _cols - _headerCols; }
    ///// set column count
    //@property override GridWidgetBase cols(int c) { resize(c, rows); return this; }
    ///// row count
    //@property override int rows() { return _rows - _headerRows; }
    ///// set row count
    //@property override GridWidgetBase rows(int r) { resize(cols, r); return this; }
    //
    ///// set new size
    //override void resize(int cols, int rows) {
    //    super.resize(cols + _headerCols, rows + _headerRows);
    //}

}

/**
 * Grid view with string data shown. All rows are of the same height
 */
class StringGridWidget : StringGridWidgetBase {

    protected dstring[][] _data;
    protected dstring[] _rowTitles;
    protected dstring[] _colTitles;

    /// empty parameter list constructor - for usage by factory
    this() {
        this(null);
    }
    /// create with ID parameter
    this(string ID) {
        super(ID);
        styleId = STYLE_STRING_GRID;
        onThemeChanged();
    }

    /// get cell text
    override dstring cellText(int col, int row) {
        if (col >= 0 && col < cols && row >= 0 && row < rows)
            return _data[row][col];
        return ""d;
    }

    /// set cell text
    override StringGridWidgetBase setCellText(int col, int row, dstring text) {
        if (col >= 0 && col < cols && row >= 0 && row < rows)
            _data[row][col] = text;
        return this;
    }

    /// set new size
    override void resize(int c, int r) {
        if (c == cols && r == rows)
            return;
        int oldcols = cols;
        int oldrows = rows;
        super.resize(c, r);
        _data.length = r;
        for (int y = 0; y < r; y++)
            _data[y].length = c;
        _colTitles.length = c;
        _rowTitles.length = r;
    }

    /// returns row header title
    override dstring rowTitle(int row) {
        return _rowTitles[row];
    }
    /// set row header title
    override StringGridWidgetBase setRowTitle(int row, dstring title) {
        _rowTitles[row] = title;
        return this;
    }

    /// returns row header title
    override dstring colTitle(int col) {
        return _colTitles[col];
    }

    /// set col header title
    override StringGridWidgetBase setColTitle(int col, dstring title) {
        _colTitles[col] = title;
        return this;
    }

    protected override Point measureCell(int x, int y) {
        if (_customCellAdapter && _customCellAdapter.isCustomCell(x, y)) {
            return _customCellAdapter.measureCell(x, y);
        }
        //Log.d("measureCell ", x, ", ", y);
        FontRef fnt = font;
        dstring txt;
        if (x >= 0 && y >= 0)
            txt = cellText(x, y);
        else if (y < 0 && x >= 0)
            txt = colTitle(x);
        else if (y >= 0 && x < 0)
            txt = rowTitle(y);
        Point sz = fnt.textSize(txt);
        if (sz.y < fnt.height)
            sz.y = fnt.height;
        return sz;
    }


    /// draw cell content
    protected override void drawCell(DrawBuf buf, Rect rc, int col, int row) {
        if (_customCellAdapter && _customCellAdapter.isCustomCell(col, row)) {
            return _customCellAdapter.drawCell(buf, rc, col, row);
        }
        if (BACKEND_GUI) 
            rc.shrink(2, 1);
        else 
            rc.right--;
        FontRef fnt = font;
        dstring txt = cellText(col, row);
        Point sz = fnt.textSize(txt);
        Align ha = Align.Left;
        //if (sz.y < rc.height)
        //    applyAlign(rc, sz, ha, Align.VCenter);
        int offset = BACKEND_CONSOLE ? 0 : 1;
        fnt.drawText(buf, rc.left + offset, rc.top + offset, txt, textColor);
    }

    /// draw cell content
    protected override void drawHeaderCell(DrawBuf buf, Rect rc, int col, int row) {
        if (BACKEND_GUI) 
            rc.shrink(2, 1);
        else 
            rc.right--;
        FontRef fnt = font;
        dstring txt;
        if (row < 0 && col >= 0)
            txt = colTitle(col);
        else if (row >= 0 && col < 0)
            txt = rowTitle(row);
        if (!txt.length)
            return;
        Point sz = fnt.textSize(txt);
        Align ha = Align.Left;
        if (col < 0)
            ha = Align.Right;
        if (row < 0)
            ha = Align.HCenter;
        applyAlign(rc, sz, ha, Align.VCenter);
        int offset = BACKEND_CONSOLE ? 0 : 1;
        fnt.drawText(buf, rc.left + offset, rc.top + offset, txt, textColor);
    }

    /// draw cell background
    protected override void drawHeaderCellBackground(DrawBuf buf, Rect rc, int c, int r) {
        bool selectedCol = (c == col) && !_rowSelect;
        bool selectedRow = r == row;
        bool selectedCell = selectedCol && selectedRow;
        if (_rowSelect && selectedRow)
            selectedCell = true;
        // draw header cell background
        uint cl = _cellHeaderBackgroundColor;
        if (c >= _headerCols || r >= _headerRows) {
            if (c < _headerCols && selectedRow)
                cl = _cellHeaderSelectedBackgroundColor;
            if (r < _headerRows && selectedCol)
                cl = _cellHeaderSelectedBackgroundColor;
        }
        buf.fillRect(rc, cl);
        static if (BACKEND_GUI) {
            uint borderColor = _cellHeaderBorderColor;
            buf.drawLine(Point(rc.right - 1, rc.bottom), Point(rc.right - 1, rc.top), _cellHeaderBorderColor); // vertical
            buf.drawLine(Point(rc.left, rc.bottom - 1), Point(rc.right - 1, rc.bottom - 1), _cellHeaderBorderColor); // horizontal
        }
    }

    /// draw cell background
    protected override void drawCellBackground(DrawBuf buf, Rect rc, int c, int r) {
        bool selectedCol = c == col;
        bool selectedRow = r == row;
        bool selectedCell = selectedCol && selectedRow;
        if (_rowSelect && selectedRow)
            selectedCell = true;
        uint borderColor = _cellBorderColor;
        if (c < fixedCols || r < fixedRows) {
            // fixed cell background
            buf.fillRect(rc, _fixedCellBackgroundColor);
            borderColor = _fixedCellBorderColor;
        }
        static if (BACKEND_GUI) {
            buf.drawLine(Point(rc.left, rc.bottom + 1), Point(rc.left, rc.top), borderColor); // vertical
            buf.drawLine(Point(rc.left, rc.bottom - 1), Point(rc.right - 1, rc.bottom - 1), borderColor); // horizontal
        }
        if (selectedCell) {
            static if (BACKEND_GUI) {
                if (_rowSelect)
                    buf.drawFrame(rc, _selectionColorRowSelect, Rect(0,1,0,1), _cellBorderColor);
                else
                    buf.drawFrame(rc, _selectionColor, Rect(1,1,1,1), _cellBorderColor);
            } else {
                if (_rowSelect)
                    buf.fillRect(rc, _selectionColorRowSelect);
                else
                    buf.fillRect(rc, _selectionColor);
            }
        }
    }


    /// handle theme change: e.g. reload some themed resources
    override void onThemeChanged() {
        super.onThemeChanged();
        _selectionColor = style.customColor("grid_selection_color", 0x804040FF);
        _selectionColorRowSelect = style.customColor("grid_selection_color_row", 0xC0A0B0FF);
        _fixedCellBackgroundColor = style.customColor("grid_cell_background_fixed", 0xC0E0E0E0);
        _cellBorderColor = style.customColor("grid_cell_border_color", 0xC0C0C0C0);
        _fixedCellBorderColor = style.customColor("grid_cell_border_color_fixed", _cellBorderColor);
        _cellHeaderBorderColor = style.customColor("grid_cell_border_color_header", 0xC0202020);
        _cellHeaderBackgroundColor = style.customColor("grid_cell_background_header", 0xC0909090);
        _cellHeaderSelectedBackgroundColor = style.customColor("grid_cell_background_header_selected", 0x80FFC040);
    }
}

//import dlangui.widgets.metadata;
//mixin(registerWidgets!(StringGridWidget)());
