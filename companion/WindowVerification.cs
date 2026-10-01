using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace RayWRT.Companion;
public partial class MainWindow
{
    void ConfigureVerification()
    {
        var args=Environment.GetCommandLineArgs();
        if(args.Contains("--wireguard-ui-test")) Loaded+=async(_,_)=>
        {
            try {
                client=new Renci.SshNet.SshClient("127.0.0.1",22,"root","fixture");await Task.Run(client.Connect);await Refresh();UpdateConnectionIndicator();WireTabClick(this,new RoutedEventArgs());UpdateLayout();
                if(!ImportWireGuard.IsEnabled||!WirePanel.IsVisible||PassPanel.IsVisible)throw new Exception("WireGuard import control unavailable.");
                SaveCapture("wireguard-import-header.png",1);
                File.WriteAllText(Path.Combine(AppContext.BaseDirectory,"wireguard-ui-test.txt"),"PASS: connected import control and WireGuard tab layout.");
            }catch(Exception ex){File.WriteAllText(Path.Combine(AppContext.BaseDirectory,"wireguard-ui-test.txt"),ex.ToString());Environment.ExitCode=1;}Close();
        };
        if(args.Contains("--add-dialog-capture")) Loaded+=async(_,_)=>{client=new Renci.SshNet.SshClient("127.0.0.1",22,"root","fixture");await Task.Run(client.Connect);AddNodeClick(this,new RoutedEventArgs());Close();};
        if(args.Contains("--add-fixture-test")) Loaded+=async(_,_)=>
        {
            try {
                NodeImport.Validate("node","vless://id@host:443","Alice's");
                try {NodeImport.Validate("subscription","file:///etc/passwd","");throw new Exception("Invalid link accepted.");}catch(Exception ex)when(ex.Message.StartsWith("Enter an HTTP")){}
                client=new Renci.SshNet.SshClient("127.0.0.1",22,"root","fixture");await Task.Run(client.Connect);await Refresh();UpdateConnectionIndicator();LoginPanel.Visibility=Visibility.Collapsed;UpdateLayout();
                if(!AddNode.IsEnabled||!PassPanel.IsVisible||WirePanel.IsVisible)throw new Exception("Add/tab state failed.");
                SaveCapture("add-header.png",1);File.WriteAllText(Path.Combine(AppContext.BaseDirectory,"add-test.txt"),"PASS: validation, connection and Add header layout.");
            }catch(Exception ex){File.WriteAllText(Path.Combine(AppContext.BaseDirectory,"add-test.txt"),ex.ToString());Environment.ExitCode=1;}Close();
        };
        if(args.Contains("--tools-fixture-test")) Loaded+=async(_,_)=>
        {
            try
            {
                client=new Renci.SshNet.SshClient("127.0.0.1",22,"root","fixture");await Task.Run(client.Connect);
                LoginPanel.Visibility=Visibility.Collapsed;Host.Text="127.0.0.1";Host.IsReadOnly=true;Connection.Content="Disconnect";await Refresh();SelectTools();
                var raw=await Command("uci -q show passwall2; uci -q show network; uci -q show wireless; true");var networks=RouterTools.Wireless(raw);
                if(networks.Count!=2||networks[0].Enabled||!networks[1].Enabled||networks[1].Key!="initial-key")throw new Exception("Wireless parsing failed.");
                await Command(RouterTools.Toggle(networks[0],!networks[0].Enabled));var after=RouterTools.Wireless(await Command("uci -q show passwall2; uci -q show network; uci -q show wireless; true"));
                if(after[0].Enabled==networks[0].Enabled||after[1].Enabled!=networks[1].Enabled)throw new Exception("Independent toggle failed.");
                await Command(RouterTools.Save(after[1],"Windows Prototype","test-key-456"));await Refresh();
                if(!RouterTools.Wireless(await Command("uci -q show passwall2; uci -q show network; uci -q show wireless; true")).Any(w=>w.Ssid=="Windows Prototype"))throw new Exception("SSID edit failed.");
                using var stream=typeof(MainWindow).Assembly.GetManifestResourceStream("RayWRT.Diagnostics")!;using var reader=new StreamReader(stream);SetPingResult(RouterTools.Ping(await Command("sh -c "+Quote(await reader.ReadToEndAsync())+" raywrt run")));
                if(!pingResult.Text.Contains("14/15 replies")||!pingResult.Text.Contains("24.0 ms")||!pingResult.Text.Contains("0%"))throw new Exception("Ping aggregation failed.");
                if(RouterTools.Save(after[1],"same","").Contains(".key="))throw new Exception("Blank password overwrite.");
                try{RouterTools.Save(after[1],"same","short");throw new Exception("Invalid password accepted.");}catch(Exception ex)when(ex.Message.StartsWith("Use a Wi-Fi")){}
                var partial=string.Join("\n",Enumerable.Range(0,15).Select(i=>$"id{i}|ok|20|24|28|25||4|{(i==0?3:4)}"));var report=RouterTools.Ping(partial);if(report.Loss!="1.67%"||report.Counts!="1/60 probes lost")throw new Exception("Actual probe loss calculation failed.");
                var ifaceOff=raw.Replace("wireless.radio0.disabled='1'","wireless.radio0.disabled='0'");if(RouterTools.Wireless(ifaceOff)[0].Enabled)throw new Exception("AP disabled flag ignored.");
                Status.Text="Prototype · fixture checks passed";UpdateConnectionIndicator();UpdateLayout();SaveCapture("router-tools.png",1);ContentScroll.ScrollToBottom();UpdateLayout();SaveCapture("router-tools-wireless.png",1);
                await Command(RouterTools.Reboot);
                File.WriteAllText(Path.Combine(AppContext.BaseDirectory,"tools-test.txt"),"PASS: fixture SSH, independent radio controls, SSID/password edits, diagnostic aggregation, reboot request, UI capture.");
            }
            catch(Exception ex){File.WriteAllText(Path.Combine(AppContext.BaseDirectory,"tools-test.txt"),ex.ToString());Environment.ExitCode=1;}
            Close();
        };
        if(args.Contains("--capture")) Loaded+=(_,_)=> {UpdateLayout();SaveCapture("app.png",1);Close();};
        if(args.Contains("--smoke-test")) Loaded+=(_,_)=>
        {
            UpdateLayout();
            var pass=Nodes.Children.Count==1 && Tunnels.Children.Count==1 && !Toggle.IsEnabled && LoginPanel.IsVisible && Status.FontSize==13 && FindName("PreviewButton")==null;
            if(!pass) Environment.Exit(1);
            Close();
        };
        if(args.Contains("--indicator-test")) Loaded+=async(_,_)=>
        {
            SetConnectionIndicator(true);UpdateLayout();
            var green=RouterStateText.Text=="Connected" && ((SolidColorBrush)ConnectionDot.Fill).Color==(Color)ColorConverter.ConvertFromString("#75DDA9");
            SaveCapture("indicator-connected.png",1);
            SetConnectionIndicator(false,true);
            var connecting=RouterStateText.Text=="Connecting…";
            SetConnectionIndicator(false);UpdateLayout();
            var red=RouterStateText.Text=="Disconnected" && ((SolidColorBrush)ConnectionDot.Fill).Color==(Color)ColorConverter.ConvertFromString("#EB7D88");
            SaveCapture("indicator-disconnected.png",1);
            ApplyHeartbeatPreference();
            var pulseEnabled=!SystemParameters.ClientAreaAnimation || ConnectionHalo.HasAnimatedProperties;
            await System.Threading.Tasks.Task.Delay(650);
            var restrained=ConnectionHalo.Opacity>=0.02 && ConnectionHalo.Opacity<=0.17;
            File.WriteAllText(Path.Combine(AppContext.BaseDirectory,"indicator-test.txt"),$"Green connected state: {green}\nConnecting label: {connecting}\nRed disconnected state: {red}\nHeartbeat honors animation preference: {pulseEnabled}\nHalo opacity stays subtle: {restrained}\n");
            if(!(green && connecting && red && pulseEnabled && restrained))Environment.Exit(1);
            Close();
        };
        if(args.Contains("--layout-test")) Loaded+=(_,_)=>
        {
            var results=new StringBuilder("resolution,scaling,width_DIP,height_DIP,footer_visible,inputs_visible,scrolling,fit\n");
            var passed=true;
            foreach(var screen in new[]{(1920,1080),(2560,1440),(3840,2160)})
            foreach(var scale in new[]{1.0,1.25,1.5,1.75,2.0,2.5,3.0})
            {
                var size=DisplayLayout.PreferredSize(screen.Item1/scale,(screen.Item2-48*scale)/scale);
                MinWidth=Math.Min(480,size.Width);MinHeight=Math.Min(480,size.Height);Width=size.Width;Height=size.Height;UpdateLayout();
                // AuthorLink is an inline; measure its containing TextBlock instead.
                var author=LogicalTreeHelper.GetParent(AuthorLink) as FrameworkElement;
                var footerVisible=author!=null && FullyVisible(author) && FullyVisible(Status);
                var inputsVisible=Host.ActualWidth>120 && Username.ActualWidth>100 && Password.ActualWidth>100;
                ContentScroll.ScrollToBottom();UpdateLayout();
                var scrolling=ContentScroll.ScrollableHeight==0 || ContentScroll.VerticalOffset>0;
                var fit=size.Width*scale<=screen.Item1 && size.Height*scale<=screen.Item2-48*scale;
                passed&=footerVisible && inputsVisible && scrolling && fit;
                results.AppendLine($"{screen.Item1}x{screen.Item2},{scale:P0},{size.Width:F0},{size.Height:F0},{footerVisible},{inputsVisible},{scrolling},{fit}");
                ContentScroll.ScrollToTop();UpdateLayout();
                if((screen.Item1==1920 && scale==1.5)||(screen.Item1==2560 && scale==1.5)||(screen.Item1==3840 && scale==2)) SaveCapture($"layout-{screen.Item1}x{screen.Item2}.png",scale);
            }
            var dpiAware=AreDpiAwarenessContextsEqual(GetThreadDpiAwarenessContext(),(nint)(-4));
            results.AppendLine($"PerMonitorV2,{dpiAware}");passed&=dpiAware;
            Width=480;Height=640;UpdateLayout();
            Status.Text="Error: Could not connect to your router. Check your router address and SSH credentials, then try again.";
            UpdateLayout();
            var readableError=FullyVisible(Status) && Status.ActualHeight>20 && FullyVisible((FrameworkElement)LogicalTreeHelper.GetParent(AuthorLink));
            results.AppendLine($"Narrow window with wrapped status,{readableError}");passed&=readableError;
            // Exercise the same configuration cards used after a real router login.
            Nodes.Children.Clear();Tunnels.Children.Clear();LoginPanel.Visibility=Visibility.Collapsed;
            AddRow(Nodes,"▤","Long configuration name for overflow checking","A long router host name.example","Inactive",false,"Set Active",()=>System.Threading.Tasks.Task.CompletedTask,true);
            AddRow(Tunnels,"◇","WireGuard interface","","Disconnected",false,"Connect",()=>System.Threading.Tasks.Task.CompletedTask,false);
            UpdateLayout();
            var rowFits=Nodes.Children[0] is FrameworkElement row && row.ActualWidth<=PassPanel.ActualWidth;
            ContentScroll.ScrollToBottom();UpdateLayout();
            var reachable=ContentScroll.ScrollableHeight==0 || ContentScroll.VerticalOffset>0;
            results.AppendLine($"Router cards in narrow window,{rowFits && reachable}");passed&=rowFits && reachable;
            WindowState=WindowState.Maximized;UpdateLayout();
            var work=DisplayLayout.WorkAreaPixels(this);
            var dpi=VisualTreeHelper.GetDpi(this);
            var maximizedFit=Math.Abs(ActualWidth*dpi.DpiScaleX-work.Width)<2 && Math.Abs(ActualHeight*dpi.DpiScaleY-work.Height)<2;
            results.AppendLine($"Maximize respects current monitor work area,{maximizedFit}");passed&=maximizedFit;
            File.WriteAllText(Path.Combine(AppContext.BaseDirectory,"layout-test.csv"),results.ToString());
            if(!passed) Environment.Exit(1);
            Close();
        };
    }
    bool FullyVisible(FrameworkElement element)
    {
        var location=element.TransformToAncestor(WindowContent).Transform(new Point(0,0));
        return location.X>=-1 && location.Y>=-1 && location.X+element.ActualWidth<=ActualWidth+1 && location.Y+element.ActualHeight<=ActualHeight+1;
    }
    void SaveCapture(string filename,double scale)
    {
        var bitmap=new RenderTargetBitmap((int)Math.Ceiling(ActualWidth*scale),(int)Math.Ceiling(ActualHeight*scale),96*scale,96*scale,PixelFormats.Pbgra32);
        bitmap.Render(this);var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var file=File.Create(Path.Combine(AppContext.BaseDirectory,filename));encoder.Save(file);
    }
    [DllImport("user32.dll")] static extern nint GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")] [return:MarshalAs(UnmanagedType.Bool)] static extern bool AreDpiAwarenessContextsEqual(nint first,nint second);
}

