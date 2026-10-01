using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;

namespace RayWRT.Companion;
internal sealed class DisplayLayout
{
    readonly Window window;
    HwndSource? source;
    bool initialFit;
    public DisplayLayout(Window window)
    {
        this.window=window;
        window.SourceInitialized+=(_,_)=>
        {
            source=HwndSource.FromHwnd(new WindowInteropHelper(window).Handle);
            source?.AddHook(WindowMessages);
        };
        window.Loaded+=(_,_)=> {Fit(true);initialFit=true;};
        window.DpiChanged+=(_,_)=>window.Dispatcher.BeginInvoke(()=>Fit(false));
        SystemParameters.StaticPropertyChanged+=OnSystemParametersChanged;
        window.Closed+=(_,_)=> {SystemParameters.StaticPropertyChanged-=OnSystemParametersChanged;source?.RemoveHook(WindowMessages);};
    }
    void OnSystemParametersChanged(object? sender,System.ComponentModel.PropertyChangedEventArgs args)
    {
        if(initialFit && args.PropertyName==nameof(SystemParameters.WorkArea)) window.Dispatcher.BeginInvoke(()=>Fit(false));
    }
    internal static Size PreferredSize(double workWidth,double workHeight)
    {
        return new Size(Math.Min(560,Math.Max(1,workWidth-32)),Math.Min(996,Math.Max(1,workHeight-32)));
    }
    void Fit(bool initial)
    {
        if(!TryMonitor(new WindowInteropHelper(window).Handle,out var monitor))return;
        var dpi=VisualTreeHelper.GetDpi(window);
        var workWidth=(monitor.Work.Right-monitor.Work.Left)/dpi.DpiScaleX;
        var workHeight=(monitor.Work.Bottom-monitor.Work.Top)/dpi.DpiScaleY;
        var fit=PreferredSize(workWidth,workHeight);
        window.MinWidth=Math.Min(480,fit.Width);
        window.MinHeight=Math.Min(480,fit.Height);
        if(window.WindowState!=WindowState.Normal)return;
        window.Width=initial?fit.Width:Math.Min(window.Width,fit.Width);
        window.Height=initial?fit.Height:Math.Min(window.Height,fit.Height);
        // WPF placement uses device-independent coordinates on the current monitor.
        var left=monitor.Work.Left/dpi.DpiScaleX;
        var top=monitor.Work.Top/dpi.DpiScaleY;
        window.Left=initial?left+(workWidth-window.Width)/2:Math.Clamp(window.Left,left,left+workWidth-window.Width);
        window.Top=initial?top+(workHeight-window.Height)/2:Math.Clamp(window.Top,top,top+workHeight-window.Height);
    }
    nint WindowMessages(nint hwnd,int message,nint wParam,nint lParam,ref bool handled)
    {
        if(message==0x0024 && TryMonitor(hwnd,out var monitor)) // WM_GETMINMAXINFO
        {
            var limits=Marshal.PtrToStructure<MinMaxInfo>(lParam);
            limits.MaxPosition=new PointI(monitor.Work.Left-monitor.Bounds.Left,monitor.Work.Top-monitor.Bounds.Top);
            limits.MaxSize=new PointI(monitor.Work.Right-monitor.Work.Left,monitor.Work.Bottom-monitor.Work.Top);
            Marshal.StructureToPtr(limits,lParam,false);
            handled=true;
        }
        else if(message==0x007E && initialFit)window.Dispatcher.BeginInvoke(()=>Fit(false)); // WM_DISPLAYCHANGE
        return 0;
    }
    static bool TryMonitor(nint hwnd,out MonitorInfo result)
    {
        result=new MonitorInfo {Size=Marshal.SizeOf<MonitorInfo>()};
        return GetMonitorInfo(MonitorFromWindow(hwnd,2),ref result);
    }
    internal static Rect WorkAreaPixels(Window window)
    {
        if(!TryMonitor(new WindowInteropHelper(window).Handle,out var monitor))return Rect.Empty;
        return new Rect(monitor.Work.Left,monitor.Work.Top,monitor.Work.Right-monitor.Work.Left,monitor.Work.Bottom-monitor.Work.Top);
    }
    [StructLayout(LayoutKind.Sequential)] struct PointI {public int X,Y;public PointI(int x,int y){X=x;Y=y;}}
    [StructLayout(LayoutKind.Sequential)] struct RectI {public int Left,Top,Right,Bottom;}
    [StructLayout(LayoutKind.Sequential)] struct MonitorInfo {public int Size;public RectI Bounds,Work;public int Flags;}
    [StructLayout(LayoutKind.Sequential)] struct MinMaxInfo {public PointI Reserved,MaxSize,MaxPosition,MinTrackSize,MaxTrackSize;}
    [DllImport("user32.dll")] static extern nint MonitorFromWindow(nint hwnd,uint flags);
    [DllImport("user32.dll",CharSet=CharSet.Auto)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool GetMonitorInfo(nint monitor,ref MonitorInfo info);
}
