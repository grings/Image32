program CtrlDemo;

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Messages,
  TypInfo,
  Img32,
  Img32.Vector,
  Img32.Draw,
  Img32.Layers,
  Img32.Ctrl,
  Img32.Text,
  Img32.Extra,
  Img32.Fmt.BMP,
  Img32.Fmt.SVG,
  Img32.SVG.Reader;

{$R Lorem.res}
{$R Images.res}
{$R storage.res}
{$R ..\resources.res}

{$WARN SYMBOL_PLATFORM OFF}

type

  TEventPropertyHandler1 = class(TEventPropertyHandler)
  private
    fArial14: TFontCache;
    fArial18: TFontCache;
    fArialStatic: TFontCache;
    fSvgList  : TSvgImageList32;
    fSvgList2 : TSvgImageList32;
  public
    procedure SaveClick(Sender: TObject);
    procedure SliderClick(Sender: TObject);
    procedure Slider2Click(Sender: TObject);
    procedure ClickMe(Sender: TObject);
    procedure DesignModeClick(Sender: TObject);

    property Arial14: TFontCache read fArial14 write fArial14;
    property Arial18: TFontCache read fArial18 write fArial18;
    property ArialStatic: TFontCache read fArialStatic write fArialStatic;
    property svgList   : TSvgImageList32 read fSvgList write fSvgList;
    property svgList2  : TSvgImageList32 read fSvgList2 write fSvgList2;
  end;

var
  WinClass: TWndClass;
  Inst, mainHdl: THandle;
  Msg: TMsg;
  sizeCursor: HIcon;
  handCursor: HIcon;
  arrowCursor: HIcon;
  eventPropHandler1: TEventPropertyHandler1;

  storageMngr : TCtrlStorageManager;
  fontReader  : TFontReader;
  layeredImg32: TLayeredImage32;
  rootCtrl    : TPanelCtrl;
  pageCtrl    : TPageCtrl;

  prevScale   : double;
  updateRect  : TRect;
  imageSize64 : double;
  imageSize24 : double;

  inDesignMode: Boolean;
  clickPt     : TPoint;
  clickLayer  : TLayer32;
  target      : TCustomCtrl;
  sizingGroup : TSizingGroupLayer32;

const
  DoLoadFromStorage = true;//false;//
  cmd_OK = 1;


//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

function IsOwnedBy(ctrl: TLayer32; ownerCtrlClass: TCustomCtrlClass): Boolean;
begin
  Result := false;
  while Assigned(ctrl.Parent) do
    if ctrl.Parent is ownerCtrlClass then
    begin
      Result := true;
      Break;
    end
    else
      ctrl := ctrl.Parent;
end;
//------------------------------------------------------------------------------

function WParamToShiftState(wParam: Word): TShiftState;
begin
  Result := 0;
  if wParam and MK_SHIFT <> 0 then Result := Result + ssShift;
  if wParam and MK_CONTROL <> 0 then Result := Result + ssCtrl;
  if GetKeyState(VK_MENU) < 0 then Result := Result + ssAlt;
end;
//------------------------------------------------------------------------------

function LParamToShiftState(lParam: LPARAM): TShiftState;
const
  AltMask = $20000000;
begin
  Result := 0;
  if GetKeyState(VK_SHIFT) < 0 then Result := Result + ssShift;
  if GetKeyState(VK_CONTROL) < 0 then Result := Result + ssCtrl;
  if lParam and AltMask <> 0 then Result := Result + ssAlt;
end;
//------------------------------------------------------------------------------

procedure SetClientRect(hdl: HWnd; width, height: Cardinal);
var
  winRec, clientRec: TRect;
  dx,dy: cardinal;
begin
  GetWindowRect(hdl, winRec);
  GetClientRect(hdl, clientRec);
  dx := winrec.Width - clientRec.Width;
  dy := winrec.Height - clientRec.Height;
  SetWindowPos(hdl, 0,0,0, width+dx,height+dy, SWP_NOZORDER or SWP_NOMOVE);
end;
//------------------------------------------------------------------------------

function CenterForm(FormHdl: THandle): boolean;
var
  DesktopRec, WindowRec: TRect;
  l,t: integer;
begin
  result := SystemParametersInfo(SPI_GETWORKAREA,0,@DesktopRec,0);
  if not result or (FormHdl = 0) then exit;
  GetWindowRect(FormHdl,WindowRec);
  l := ((DesktopRec.Right-DesktopRec.Left)-(WindowRec.Right-WindowRec.Left)) div 2;
  t := ((DesktopRec.Bottom-DesktopRec.Top)-(WindowRec.Bottom-WindowRec.Top)) div 2;
  if l < 0 then l := 0;
  if t < 0 then t := 0;
  result := SetWindowPos(FormHdl,0,l,t,0,0,SWP_NOACTIVATE or SWP_NOSIZE or SWP_NOZORDER);
end;
//------------------------------------------------------------------------------

procedure SetTarget(ctrl: TCustomCtrl);
begin
  if ctrl = target then Exit;
  FreeAndNil(sizingGroup);
  target := ctrl;
  if Assigned(target) then
    sizingGroup := CreateSizingButtonGroup(target, ssCorners,
      bsRound, DefaultButtonSize, clLime32);
  InvalidateRect(mainHdl, nil, false);
end;
//------------------------------------------------------------------------------

procedure DoScale(scale: double);
var
  scaleDelta: double;
  loadScale : double;
  ImgSz     : integer;
begin
  scaleDelta := scale/prevScale;
  prevScale := scale;
  if storageMngr.DesignScreenRes > 0 then
    loadScale := storageMngr.DesignScreenRes / DpiAwareOne else
    loadScale := 1;
  StorageMngr.DesignFormScale := scale;

  with eventPropHandler1 do
  begin
    ArialStatic.FontHeight := DpiAware(14) * loadScale;
    arial14.FontHeight := DpiAware(14) * loadScale * scale;
    arial18.FontHeight := DpiAware(18) * loadScale * scale;

    ImgSz := Round(imageSize64 * loadScale * scale);
    svgList.DefaultWidth := ImgSz;
    svgList.DefaultHeight := ImgSz;

    ImgSz := Round(imageSize24 * loadScale * scale);
    svgList2.DefaultWidth := ImgSz;
    svgList2.DefaultHeight := ImgSz;
  end;

  with storageMngr do
    FocusedLineWidth := DPIAware(1.25) * LoadScale * scale;

  if not ValueAlmostOne(scaleDelta) then
    pageCtrl.Scale(scaleDelta);
  InvalidateRect(mainHdl, nil, false);
end;
//------------------------------------------------------------------------------

procedure TEventPropertyHandler1.SaveClick(Sender: TObject);
var
  wp: TWindowPlacement;
begin
  wp.length := SizeOf(wp);
  GetWindowPlacement(mainHdl, wp);
  with wp.rcNormalPosition do
    SetWindowPos(mainHdl,0,Left,Top,Right-Left,Bottom-Top,
      SWP_NOACTIVATE or SWP_NOZORDER);
  storageMngr.SaveToFile('CtrlDemo.xml', StorageMngr.DesignFormScale,
    [TSizingGroupLayer32, TRotatingGroupLayer32, TButtonGroupLayer32]);
end;
//------------------------------------------------------------------------------

procedure TEventPropertyHandler1.SliderClick(Sender: TObject);
var
  senderPos, scale: double;
begin
  if not Assigned(sender) or not (Sender is TSliderCtrl) then Exit;

  senderPos := (Sender as TSliderCtrl).Position;
  scale := (100 + senderPos) * 0.01;
  DoScale(scale);
end;
//------------------------------------------------------------------------------

procedure TEventPropertyHandler1.Slider2Click(Sender: TObject);
var
  senderPos: double;
begin
  senderPos := (Sender as TSliderCtrl).Position;
  with pageCtrl.FindByClass(TProgressCtrl) as TProgressCtrl do
    Position := senderPos;
end;
//------------------------------------------------------------------------------

procedure TEventPropertyHandler1.ClickMe(Sender: TObject);
begin
  with (Sender as TCustomCtrl) do
    if pos('&', Text) = 0 then
    begin
      Text := 'Click &Me';
      Color := clNone32;
    end else
    begin
      Text := 'Clicked!';
      Color := clYellow32;
    end;
end;
//------------------------------------------------------------------------------

procedure TEventPropertyHandler1.DesignModeClick(Sender: TObject);
begin
  inDesignMode := TCheckboxCtrl(Sender).TriState = tsChecked;
  if not inDesignMode then SetTarget(nil);
end;
//------------------------------------------------------------------------------

function WindowProc(hWnd, uMsg,	wParam: WPARAM; lParam: LPARAM): Integer; stdcall;
var
  key : Word;
  w,h : integer;
  pt  : TPoint;
  ps  : TPAINTSTRUCT;
  dc  : HDC;
  img : TImage32;
  dx,dy : integer;
  rec   : TRectD;
  shift : TShiftState;
  layer : TLayer32;
begin
  case uMsg of
    WM_LBUTTONDOWN:
      begin
        Result := 0;
        clickPt := Img32.vector.Point(LoWord(lParam), HiWord(lParam));
        if inDesignMode then
        begin
          clickLayer := layeredImg32.GetLayerAt(clickPt);
          if IsOwnedBy(clickLayer, TPagePnlCtrl) then
          begin
            SetTarget(clickLayer as TCustomCtrl);
            SetCursor(handCursor);
            Exit;
          end
          else if (clickLayer is TButtonDesignerLayer32) then
          begin
            SetCursor(sizeCursor);
            Exit;
          end;

          SetTarget(nil);
          clickLayer := nil;
        end;

        storageMngr.MouseDown(mbLeft, WParamToShiftState(wParam), clickPt);
        if storageMngr.RepaintRequired then
          InvalidateRect(hWnd, nil, false);
      end;
    WM_MOUSEMOVE:
      begin
        Result := 0;
        pt := Img32.vector.Point(LoWord(lParam), HiWord(lParam));
        dx := pt.X - clickPt.X; dy := pt.Y - clickPt.Y;

        if inDesignMode then
        begin
          if not assigned(clickLayer) then
          begin
            layer := layeredImg32.GetLayerAt(pt);
            if Assigned(layer) then
            begin
              if (layer is TButtonDesignerLayer32) then
                SetCursor(sizeCursor)
              else if layer = target then
                SetCursor(handCursor)
              else
                SetCursor(arrowCursor);
            end;
            Exit;
          end;

          if clickLayer = target then
          begin
            SetCursor(handCursor);
            target.Offset(dx,dy);
            sizingGroup.Offset(dx,dy);
            clickPt := pt;
            InvalidateRect(hWnd, nil, false);
          end else if (clickLayer is TButtonDesignerLayer32) then
          begin
            SetCursor(sizeCursor);
            clickLayer.Offset(dx, dy);
            rec := RectD(UpdateSizingButtonGroup(clickLayer));
            rec := target.Parent.MakeRelative(rec);
            target.SetInnerBounds(rec);
            clickPt := pt;
            InvalidateRect(hWnd, nil, false);
          end;
        end else
        begin
          storageMngr.MouseMove(mbLeft, WParamToShiftState(wParam), pt);
          if storageMngr.RepaintRequired then
            InvalidateRect(hWnd, nil, false);
        end;
      end;
    WM_LBUTTONUP:
      begin
        if inDesignMode then clickLayer := nil;
        clickPt := Img32.vector.Point(LoWord(lParam), HiWord(lParam));
        storageMngr.MouseUp(mbLeft, WParamToShiftState(wParam), clickPt);
        if storageMngr.RepaintRequired then
          InvalidateRect(hWnd, nil, false);
        Result := 0;
      end;
    WM_MOUSEWHEEL:
      begin
        Result := 0;
      end;
    WM_SYSCOMMAND:
      if wParam = SC_KEYMENU then
        Result := 0 else //stops beeps with Alt key combos
        Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
    WM_SYSKEYDOWN,
    WM_KEYDOWN:
      begin
        key := Word(wParam);
        shift := LParamToShiftState(lParam);

        if (key = VK_ESCAPE) then
        begin
          PostQuitMessage(0);
        end

        else if inDesignMode and Assigned(Target) then
        begin
          case Key of
            VK_DELETE:
              begin
                FreeAndNil(sizingGroup);
                FreeAndNil(target);
                InvalidateRect(hWnd, nil, false);
              end;
            VK_DOWN:
              begin
                if Shift and ssCtrl <> 0 then w := 5 else w := 1;
                target.Offset(0,w);
                sizingGroup.Offset(0,w);
                InvalidateRect(hWnd, nil, false);
              end;
            VK_UP:
              begin
                if Shift and ssCtrl <> 0 then w := 5 else w := 1;
                target.Offset(0,-w);
                sizingGroup.Offset(0,-w);
                InvalidateRect(hWnd, nil, false);
              end;
            VK_RIGHT:
              begin
                if Shift and ssCtrl <> 0 then w := 5 else w := 1;
                target.Offset(w,0);
                sizingGroup.Offset(w,0);
                InvalidateRect(hWnd, nil, false);
              end;
            VK_LEFT:
              begin
                if Shift and ssCtrl <> 0 then w := 5 else w := 1;
                target.Offset(-w,0);
                sizingGroup.Offset(-w,0);
                InvalidateRect(hWnd, nil, false);
              end;
          end;
        end

        else
        begin
          storageMngr.KeyDown(key, shift);
          if storageMngr.RepaintRequired then
            InvalidateRect(hWnd, nil, false);
        end;
        Result := 0;
      end;
    WM_SYSKEYUP,
    WM_KEYUP:
      begin
        key := Word(wParam);
        shift := LParamToShiftState(lParam);
        storageMngr.KeyUp(key, shift);
        if storageMngr.RepaintRequired then
          InvalidateRect(hWnd, nil, false);
        Result := 0;
      end;
    WM_SIZE:
      begin
        w := LoWord(lParam);
        h := HIWord(lParam);
        storageMngr.Resize(w,h);
        InvalidateRect(hWnd,nil,true);
        Result := 0;
      end;
    WM_PAINT:
      begin
        Result := 0;
        img := layeredImg32.GetMergedImage(false, updateRect);
        if not Assigned(img) then Exit;
        dc := BeginPaint(hWnd, &ps);
        //FillRect(dc, &ps.rcPaint, (COLOR_BTNFACE+1));
        img.CopyToDc(updateRect, dc, updateRect.Left, updateRect.Top);
        EndPaint(hWnd, &ps);
      end;
    WM_ERASEBKGND: Result := 1;
    WM_GETDLGCODE: Result := DLGC_WANTALLKEYS;
    WM_DPICHANGED:
      begin
        //nb: Manifest DPI Awareness must be set to
        //at least 'Per Monitor' to receive this notification.
        DpiAwareOne := LoWord(wParam)/96;
        DpiAware1 := Round(DpiAwareOne);
        Result := 0;
      end;
    WM_DESTROY:
      begin
        PostQuitMessage(0);
        result := 0;
        exit;
      end;
    else
      Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
  end;
end;
//------------------------------------------------------------------------------

procedure SetupCtrls;
var
  i, pad    : integer;
  j,k,h,w   : double;
  bevelSize  : double;
  pagePnl     : TPagePnlCtrl;
  topPnlCtrl  : TPanelCtrl;
  sliderCtrl  : TSliderCtrl;
  lorem       : string;
  rs          : TResourceStream;
begin
  prevScale := 1;
  bevelSize := DPIAware(2);
  rs := TResourceStream.CreateFromID(hInstance, 1, 'TEXT');
  try
    SetLength(lorem, rs.Size div 2 -1);
    rs.Position := 2;
    rs.ReadBuffer(lorem[1], rs.Size -2);
  finally
    rs.Free;
  end;

  layeredImg32 := storageMngr.AddChild(TLayeredImage32) as TLayeredImage32;

  //outer ctrl that's an easy way to create a margin around a page ctrl
  rootCtrl := layeredImg32.AddLayer(TPanelCtrl) as TPanelCtrl;
  rootCtrl.Font := eventPropHandler1.arialStatic;
  rootCtrl.CanFocus := false;
  rootCtrl.Color := clBtnFace32;
  rootCtrl.Margin := 50;

  with layeredImg32.AddLayer(TStatusbarCtrl, rootCtrl) as TStatusbarCtrl do
  begin
    BevelHeight := DPIAware(1.5);
    Color := clNone32;
    AutoPosition := apBottom;
  end;

  topPnlCtrl := layeredImg32.AddLayer(TPanelCtrl, rootCtrl) as TPanelCtrl;
  topPnlCtrl.AutoPosition := apTop;
  topPnlCtrl.Height := DPIAware(40);
  topPnlCtrl.Color := clNone32;
  topPnlCtrl.BevelHeight := 0;
  topPnlCtrl.ShadowSize := DPIAware(10);

  //filler panel
  with layeredImg32.AddLayer(TPanelCtrl, rootCtrl) as TPanelCtrl do
  begin
    AutoPosition := apTop;
    Height := DPIAware(20);
    Color := clNone32;
    BevelHeight := 0;
  end;

  sliderCtrl := layeredImg32.AddLayer(TSliderCtrl, topPnlCtrl) as TSliderCtrl;
  with sliderCtrl do
  begin
    Orientation := soHorizontal;
    SetInnerBounds(DPIAware(RectD(70, 5, 400, 20)));
    BevelHeight := DPIAware(2);
    Min := -50;
    Max := 100;
    Position := 0;
    OnSlider := eventPropHandler1.SliderClick;
  end;

  with layeredImg32.AddLayer(TLabelCtrl, topPnlCtrl,'') as TLabelCtrl do
  begin
    Text := '&Scale:';
    SetInnerBounds(DPIAware(RectD(20, 5, 70, 25)));
    TargetCtrl := sliderCtrl;
  end;

  with layeredImg32.AddLayer(TButtonCtrl, topPnlCtrl,'') as TButtonCtrl do
  begin
    Text := 'S&ave';
    SetInnerBounds(DPIAware(RectD(420, 2, 510, 32)));
    BevelHeight := bevelSize;
    OnClick := eventPropHandler1.SaveClick;
  end;

  with layeredImg32.AddLayer(TCheckboxCtrl, topPnlCtrl,'') as TCheckboxCtrl do
  begin
    Text := '&Design Mode';
    SetInnerBounds(DPIAware(RectD(530, 2, 660, 32)));
    BevelHeight := bevelSize;
    TriState := tsUnchecked;
    OnClick := eventPropHandler1.DesignModeClick;
  end;

  //add a page control with 3 tabs
  pageCtrl := layeredImg32.AddLayer(TPageCtrl, rootCtrl) as TPageCtrl;
  pageCtrl.AutoPosition := apClient;
  pageCtrl.BevelHeight := DPIAware(3);
  pageCtrl.AddTabs(['Page &1', 'Page &2', 'Page &Three']);
  pageCtrl.Font := eventPropHandler1.arial14;

  //now add a number of ctrls to each page

  // PAGE 1 ///////////////////////////////////////////////////////
  pagePnl := pageCtrl.Panel[0];
  //pagePnl.Color := $20FFFF00; //try it :)

  with layeredImg32.AddLayer(TButtonCtrl, pagePnl) as TButtonCtrl do
  begin
    Padding := DPIAware(10);
    Text := 'Click &Me';
    SetInnerBounds(DPIAware(RectD(40, 50, 150, 85)));
    BevelHeight := bevelSize;
    Onclick := eventPropHandler1.ClickMe;
  end;

  with layeredImg32.AddLayer(TRoundedBtnCtrl, pagePnl) as TButtonCtrl do
  begin
    Text := 'Button2';
    SetInnerBounds(DPIAware(RectD(40, 100, 150, 135)));
    BevelHeight := bevelSize;
  end;

  with layeredImg32.AddLayer(TEllipseBtnCtrl, pagePnl) as TButtonCtrl do
  begin
    Text := 'Button3';
    //Color := clDefLite32;
    SetInnerBounds(DPIAware(RectD(40, 150, 150, 190)));
    BevelHeight := bevelSize;
  end;

  with layeredImg32.AddLayer(TButtonCtrl, pagePnl) as TButtonCtrl do
  begin
    Text := 'Disabled';
    SetInnerBounds(DPIAware(RectD(40, 205, 150, 240)));
    Enabled := false;
    BevelHeight := bevelSize;
  end;

  with layeredImg32.AddLayer(TCheckboxCtrl, pagePnl) as TCheckboxCtrl do
  begin
    Text := 'Tri-state checkbox';
    SetInnerBounds(DPIAware(RectD(180, 50, 380, 70)));
    BevelHeight := bevelSize;
  end;

  with layeredImg32.AddLayer(TRadioBtnCtrl, pagePnl) as TRadioBtnCtrl do
  begin
    Text := 'Tri-state radiobutton';
    SetInnerBounds(DPIAware(RectD(180, 90, 380, 110)));
    BevelHeight := bevelSize;
  end;

  with layeredImg32.AddLayer(TSliderCtrl, pagePnl) as TSliderCtrl do
  begin
    Name := 'sliderCtrl2';
    Orientation := soHorizontal;
    SetInnerBounds(DPIAware(RectD(180, 140, 400, 160)));
    Min := 0; Max := 100;
    Position := 10; //set position first otherwise the
    //OnSlider event will try to find progressCtrl which
    //doesn't currently exist
    OnSlider := eventPropHandler1.Slider2Click;
    BevelHeight := bevelSize;
  end;

  with layeredImg32.AddLayer(TProgressCtrl, pagePnl) as TProgressCtrl do
  begin
    Orientation := soHorizontal;
    SetInnerBounds(DPIAware(RectD(180, 180, 400, 200)));
    EndColor := clRed32;
    Position := 10;
    BevelHeight := bevelSize;
  end;

  with layeredImg32.AddLayer(TEditCtrl, pagePnl) as TEditCtrl do
  begin
    SetInnerBounds(DPIAware(RectD(180, 220, 400, 250)));
    Text := 'This is a test.';
    BevelHeight := bevelSize;
  end;

  with layeredImg32.AddLayer(TListCtrl, pagePnl) as TListCtrl do
  begin
    SetInnerBounds(DPIAware(RectD(430, 50, 560, 160)));
    Text := 'List Item 1'#10'List Item 2'#10'List Item 3'#10'List Item 4'#10+
      'List Item 5'#10'List Item 6'#10'List Item 7'#10'List Item 8';
    BevelHeight := bevelSize;
    MaxVisibleItems := 6;
    Margin := 0;//2;
    ImageList := eventPropHandler1.svgList2;
    ScrollV := layeredImg32.AddLayer(TScrollCtrl, nil) as TScrollCtrl;
    ScrollV.Name := 'ListScroll';
  end;

  // PAGE 2 ///////////////////////////////////////////////////////

  pagePnl := pageCtrl.Panel[1];
  //pagePnl.Color := $20FF00FF;
  //pagePnl.Margin := DPIAware(50); //margin only works for autopositioned ctrls
  //add vertical and horizontal scrollbars
  pagePnl.ScrollH :=
    layeredImg32.AddLayer(TScrollCtrl, pagePnl) as TScrollCtrl;
  pagePnl.ScrollV :=
    layeredImg32.AddLayer(TScrollCtrl, pagePnl) as TScrollCtrl;
  //pagePnl.ScrollH.ScrollSize := DPIAware(16);

  with layeredImg32.AddLayer(TLabelCtrl, pagePnl,'') as TLabelCtrl do
  begin
    Text := 'These buttons use SVG images because they are ideal for scaling.';
    SetInnerBounds(DPIAware(RectD(50, 40, 480, 62)));
  end;

  //we're about to add a whole number of image buttons
  //so we'll do this in a loop

  //prepare for button positioning
  pad := DPIAware(4);
  w := bevelSize*2 + pad*2 + imageSize64; //top row button width (bevel, padding & image)
  h := imageSize64 + pad*3 +bevelSize*2 +eventPropHandler1.arial14.LineHeight;  //button height
  j := DPIAware(50);    //initial button X offset
  k := DPIAware(80);    //initial button Y offset

  for i := 0 to eventPropHandler1.svgList.Count -1 do
    with layeredImg32.AddLayer(TImageBtnCtrl, pagePnl) as TImageBtnCtrl do
    begin
      //Font := arial;
      Text := 'Btn' + Format('%d', [i+1]);
      Padding := pad;
      BevelHeight := bevelSize;
      SetInnerBounds(RectD(j, k, j + w, k + h));
      if i mod 8 = 7 then
      begin
        j := DPIAware(50*prevScale);
        k := k + h +OuterMargin;
        //change button width and height for second row
        w := eventPropHandler1.arial14.GetTextWidth('Btn13')
          +16 + bevelSize*2 + pad*3 + imageSize64;
        h := imageSize64 + pad*2 +bevelSize*2;
      end else
        j := j + w +OuterMargin;

      //alternate text positions
      if i > 7 then
      begin
        if Odd(i) then
          TextPosition := tpRight else
          TextPosition := tpLeft;
      end else
      begin
        if Odd(i) then
          TextPosition := tpBottom else
          TextPosition := tpTop;
      end;
      ImageList := eventPropHandler1.svgList;
      ImageListIdx := i;
      //Color := clBtnFace32;
    end;

  // PAGE 3 ///////////////////////////////////////////////////////
  pagePnl := pageCtrl.Panel[2];
  //pagePnl.Color := $2000FFFF;
  pagePnl.Margin := DpiAware(10);
  pageCtrl.ActiveIndex := 0;

  with layeredImg32.AddLayer(TMemoCtrl, pagePnl) as TMemoCtrl do
  begin
    Text := lorem;
    Font := eventPropHandler1.arial18;
    BevelHeight := bevelSize;
    AutoPosition := apClient;
    ScrollV := RootOwner.AddLayer(TScrollCtrl, nil) as TScrollCtrl;
    OuterMargin := 40;
  end;
end;
//------------------------------------------------------------------------------

begin
  {Register Custom WndClass ...}
  Inst := hInstance;
  with WinClass do
  begin
    style              := CS_CLASSDC or CS_PARENTDC;
    lpfnWndProc        := @WindowProc;
    hInstance          := Inst;
    hbrBackground      := COLOR_BTNFACE + 1;
    lpszClassname      := 'IMG32_DEMO';
    hIcon              := LoadIcon(hInstance,'MAINICON');
    hCursor            := LoadCursor(0, IDC_ARROW);
  end;
  RegisterClass(WinClass);

  {Create Main Window and center it on the desktop...}
  mainHdl := CreateWindow('IMG32_DEMO', 'Demo',
              WS_OVERLAPPEDWINDOW, 0, 0,
              DpiAware(800), DpiAware(600), 0, 0, Inst, nil);
  CenterForm(mainHdl);

///////////////////////////////////////////////////////////////
  sizeCursor := LoadCursor(0, IDC_SIZEALL);
  handCursor := LoadCursor(0, IDC_HAND);
  arrowCursor := LoadCursor(0, IDC_ARROW);
  imageSize64 := DpiAware(64.0);
  imageSize24 := DpiAware(24.0);

  fontReader := FontManager.Load('Arial');

  eventPropHandler1 := TEventPropertyHandler1.Create;
  with eventPropHandler1 do
  begin
    //all the following objects will be freed by eventPropHandler1

    arial14 := TFontCache.Create(fontReader, DPIAware(14));
    arialStatic := TFontCache.Create(fontReader, DPIAware(14));
    arial18 := TFontCache.Create(fontReader, DPIAware(18));

    svgList  := TSvgImageList32.Create;
    svgList.ResourceName := 'SVG';  //automatically loads resource
    svgList.DefaultWidth := Round(imageSize64);
    svgList.DefaultHeight := Round(imageSize64);

    svgList2  := TSvgImageList32.Create;
    svgList2.ResourceName := 'SVG'; //automatically loads resource
    svgList2.DefaultWidth := Round(imageSize24);
    svgList2.DefaultHeight := Round(imageSize24);
  end;

  storageMngr := TCtrlStorageManager.Create;
  //attach the eventhandler before reading or writing to storage.
  storageMngr.EventAndPropertyHandler := eventPropHandler1;

  if DoLoadFromStorage then
  begin
    //storageMngr.LoadFromResource('CTRLS', 'STORAGE');
    storageMngr.LoadFromFile('CtrlDemo.xml');
    prevScale := storageMngr.DesignFormScale;

    layeredImg32 := storageMngr.FindByClass(TLayeredImage32) as TLayeredImage32;
    if Assigned(layeredImg32) and Assigned(layeredImg32.Root) then
    begin
      rootCtrl := layeredImg32.root[0] as TPanelCtrl;
      pageCtrl := rootCtrl.FindByClass(TPageCtrl) as TPageCtrl;
      DoScale(prevScale);

      SetClientRect(mainHdl, layeredImg32.Width, layeredImg32.Height);
    end;
  end else
  begin
    SetupCtrls;
    storageMngr.FindAllShortcutOwners;
  end;

///////////////////////////////////////////////////////////////

  ShowWindow(mainHdl, cmdShow);
  UpdateWindow(mainHdl);

  while GetMessage(Msg, 0, 0, 0) do
    begin
      TranslateMessage(msg);
      DispatchMessage(msg);
    end;

  storageMngr.free;
  eventPropHandler1.Free;
  //nb: fontReader is freed by Img32.Text.FontManager

  Halt(0);
end.


