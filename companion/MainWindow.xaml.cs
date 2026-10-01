using System.IO;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Renci.SshNet;

namespace RayWRT.Companion;
public partial class MainWindow : Window
{
    SshClient? client;
    bool busy, enabled;
    readonly string settingsPath = Path.Combine(AppContext.BaseDirectory, "router-settings.json");
    Dictionary<string,string> fingerprints = new();
    string active = "";
    public MainWindow()
    {
        InitializeComponent();
        InitializeTools();
        PassTabClick(this,new RoutedEventArgs());
        _ = new DisplayLayout(this);
        InitializeConnectionIndicator();
        var logoVisual = new DrawingVisual();
        using(var drawing = logoVisual.RenderOpen()) drawing.DrawImage((DrawingImage)FindResource("BrandLogo"),new Rect(0,0,64,64));
        var logoBitmap = new System.Windows.Media.Imaging.RenderTargetBitmap(64,64,96,96,PixelFormats.Pbgra32);
        logoBitmap.Render(logoVisual);
        Icon = logoBitmap;
        if(Environment.GetCommandLineArgs().Contains("--export-logo")) Loaded += (_,_) =>
        {
            var encoder = new System.Windows.Media.Imaging.PngBitmapEncoder();
            encoder.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(logoBitmap));
            using var file = File.Create(Path.Combine(AppContext.BaseDirectory,"logo.png"));
            encoder.Save(file);Close();
        };
        try { if(File.Exists(settingsPath)) fingerprints = JsonSerializer.Deserialize<Dictionary<string,string>>(File.ReadAllText(settingsPath)) ?? new(); } catch { }
        Empty(Nodes,"Connect to load your Passwall configurations."); Empty(Tunnels,"Connect to load your WireGuard tunnels."); Toggle.IsEnabled=false;
        Closed += (_,_) => client?.Dispose();
        if(Environment.GetCommandLineArgs().Contains("--window-test")) Loaded += (_,_) =>
        {
            UpdateLayout();
            var blankHeader = TitleBar.InputHitTest(new Point(350, 60)) as DependencyObject;
            var closeControl = TitleBar.InputHitTest(new Point(TitleBar.ActualWidth - 30, 25)) as DependencyObject;
            var bitmap = new System.Windows.Media.Imaging.RenderTargetBitmap((int)ActualWidth,(int)ActualHeight,96,96,PixelFormats.Pbgra32);
            bitmap.Render(this);
            var corner = new byte[4];
            bitmap.CopyPixels(new Int32Rect(0,0,1,1),corner,4,0);
            var passed = WindowStyle == WindowStyle.None && AllowsTransparency && blankHeader != null && !IsWindowControl(blankHeader) && IsWindowControl(closeControl) && corner[3] == 0 && ContentScroll.VerticalScrollBarVisibility == ScrollBarVisibility.Hidden;
            File.WriteAllText(Path.Combine(AppContext.BaseDirectory,"window-test.txt"),$"Borderless: {WindowStyle == WindowStyle.None}\nRounded transparent corner: {corner[3] == 0}\nEmpty header accepts dragging: {blankHeader != null && !IsWindowControl(blankHeader)}\nWindow controls excluded from dragging: {IsWindowControl(closeControl)}\n");
            if(!passed) Environment.Exit(1);
            Close();
        };
        ConfigureVerification();
    }
    static Brush Brush(string hex) => (Brush)new BrushConverter().ConvertFromString(hex)!;
    void Empty(StackPanel p,string text) { p.Children.Clear(); p.Children.Add(new TextBlock {Text=text,Foreground=Brush("#94A5B4"),Margin=new Thickness(0,10,0,14),TextWrapping=TextWrapping.Wrap}); }
    static bool IsWindowControl(DependencyObject? source)
    {
        while(source != null)
        {
            if(source is System.Windows.Controls.Primitives.ButtonBase) return true;
            source = source is Visual ? VisualTreeHelper.GetParent(source) : LogicalTreeHelper.GetParent(source);
        }
        return false;
    }
    void UpdateWindowClip(object sender, SizeChangedEventArgs e)
    {
        var radius = WindowState == WindowState.Maximized ? 0 : 18;
        WindowSurface.CornerRadius = new CornerRadius(radius);
        WindowContent.Clip = new RectangleGeometry(new Rect(0, 0, e.NewSize.Width, e.NewSize.Height), radius, radius);
    }
    void DragHeader(object sender,MouseButtonEventArgs e)
    {
        if(IsWindowControl(e.OriginalSource as DependencyObject)) return;
        e.Handled = true;
        if(e.ClickCount == 2) { Maximize(sender,e); return; }
        if(e.LeftButton != MouseButtonState.Pressed) return;
        if(WindowState == WindowState.Maximized)
        {
            var cursor = PointToScreen(e.GetPosition(this));
            var ratio = e.GetPosition(this).X / ActualWidth;
            var restoredWidth = RestoreBounds.Width;
            var headerOffset = e.GetPosition((IInputElement)sender).Y;
            var transform = PresentationSource.FromVisual(this)?.CompositionTarget?.TransformFromDevice ?? Matrix.Identity;
            var logicalCursor = transform.Transform(cursor);
            WindowState = WindowState.Normal;
            Left = logicalCursor.X - restoredWidth * ratio;
            Top = logicalCursor.Y - headerOffset;
        }
        DragMove();
    }
    void Minimize(object s,RoutedEventArgs e)=>WindowState=WindowState.Minimized;
    void Maximize(object s,RoutedEventArgs e)=>WindowState=WindowState==WindowState.Maximized?WindowState.Normal:WindowState.Maximized;
    void Exit(object s,RoutedEventArgs e)=>Close();
    void AuthorLinkNavigate(object sender,System.Windows.Navigation.RequestNavigateEventArgs e)
    {
        e.Handled=true;
        try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("https://github.com/Heygoodbye"){UseShellExecute=true}); }
        catch(Exception ex) { Status.Text="Could not open GitHub: "+ex.Message; }
    }
    async Task Run(Func<Task> work)
    {
        if(busy)return; busy=true; BodyContent.IsEnabled=false;FooterControls.IsEnabled=false;
        try { await work(); } catch(Exception ex) { Status.Text="Error: "+ex.Message; if(client?.IsConnected!=true) Connection.Content="Reconnect"; }
        finally { busy=false; BodyContent.IsEnabled=true;FooterControls.IsEnabled=true; UpdateConnectionIndicator(); }
    }
    async Task<string> Command(string command,int timeoutSeconds=25)
    {
        if(client?.IsConnected!=true) throw new InvalidOperationException("Connect to your router first.");
        return await Task.Run(()=> { using var cmd=client.CreateCommand(command); cmd.CommandTimeout=TimeSpan.FromSeconds(timeoutSeconds); var output=cmd.Execute(); if(cmd.ExitStatus!=0) throw new Exception(string.IsNullOrWhiteSpace(cmd.Error)?"Router command failed.":cmd.Error.Trim()); return output; });
    }
    async void ConnectClick(object s,RoutedEventArgs e) => await Run(async()=>
    {
        if(client?.IsConnected==true) { client.Dispose();client=null;Connection.Content="Connect";LoginPanel.Visibility=Visibility.Visible;Host.IsReadOnly=false;Toggle.IsEnabled=false;Empty(Nodes,"Connect to load configurations.");Empty(Tunnels,"Connect to load tunnels.");Status.Text="Disconnected.";return; }
        var host=Host.Text.Trim(); var user=Username.Text.Trim(); var password=Password.Password;
        if(!System.Net.IPAddress.TryParse(host,out _) && !Regex.IsMatch(host,@"^[a-zA-Z0-9][a-zA-Z0-9.-]*$")) throw new Exception("Enter a valid router IP or hostname.");
        var next=new SshClient(host,22,user,password); next.ConnectionInfo.Timeout=TimeSpan.FromSeconds(12);
        next.KeepAliveInterval=TimeSpan.FromSeconds(15);
        next.ErrorOccurred+=(_,_)=>
        {
            if(!Dispatcher.HasShutdownStarted) Dispatcher.BeginInvoke(()=>
            {
                if(ReferenceEquals(client,next))
                {
                    Connection.Content="Reconnect";
                    Toggle.IsEnabled=false;
                    LoginPanel.Visibility=Visibility.Visible;
                    Host.IsReadOnly=false;
                    SetConnectionIndicator(false);
                    Status.Text="Router disconnected. Connect again to continue.";
                }
            });
        };
        next.HostKeyReceived += (_,args)=> {
            var key=Convert.ToBase64String(SHA256.HashData(args.HostKey));
            fingerprints.TryGetValue(host,out var known);
            if(known==key){args.CanTrust=true;return;}
            var message=known==null?"Trust this router's SSH host key?":"Router identity changed. Reinstalling OpenWrt can cause this. Verify the new fingerprint with your router before trusting it.\n\nPrevious SHA256:"+known;
            args.CanTrust=Dispatcher.Invoke(()=>MessageBox.Show(this,message+"\n\n"+host+"\nNew SHA256:"+key,known==null?"Router identity":"Router identity changed",MessageBoxButton.YesNo,MessageBoxImage.Question)==MessageBoxResult.Yes);
            if(args.CanTrust) Dispatcher.Invoke(()=> { fingerprints[host]=key; try { File.WriteAllText(settingsPath,JsonSerializer.Serialize(fingerprints)); } catch { Status.Text="Host key trusted for this session; settings folder is read-only."; } });
        };
        Status.Text="Connecting…";
        SetConnectionIndicator(false,true);
        try { await Task.Run(next.Connect); } catch { next.Dispose();throw; }
        client?.Dispose();client=next;Password.Clear();Connection.Content="Disconnect";LoginPanel.Visibility=Visibility.Collapsed;Host.IsReadOnly=true;UpdateConnectionIndicator();await Refresh();
    });
    static string Quote(string s)=>"'"+s.Replace("'","'\\''")+"'";
    static Dictionary<string,string> Parse(string text)=>text.Split('\n').Where(x=>x.Contains('=')).Select(x=>x.Split('=',2)).GroupBy(x=>x[0]).ToDictionary(x=>x.Key,x=>x.Last()[1].Trim().Trim('\''));
    async Task Refresh()
    {
        var raw=await Command("uci -q show passwall2; uci -q show network; uci -q show wireless; true");
        var data=RouterTools.Parse(raw);RenderWifi(RouterTools.Wireless(raw,await Command("ubus call network.wireless status 2>/dev/null || printf '{}'")));
        var global=data.FirstOrDefault(x=>x.Key.StartsWith("passwall2.") && x.Value=="global").Key;
        active=global!=null?data.GetValueOrDefault(global+".node",""):"";
        enabled=global!=null && data.GetValueOrDefault(global+".enabled")=="1";
        Toggle.Content=enabled?"Enabled":"Disabled";Toggle.IsEnabled=global!=null;Toggle.Tag=global;
        Nodes.Children.Clear();
        foreach(var pair in data.Where(x=>x.Key.StartsWith("passwall2.") && x.Value=="nodes"))
        {
            var id=pair.Key["passwall2.".Length..];var name=data.GetValueOrDefault(pair.Key+".remarks",id);var selected=id==active;
            AddRow(Nodes,"▤",name,selected?"Currently in use":data.GetValueOrDefault(pair.Key+".address","Configured node"),selected?"Active":"Inactive",selected,selected?"Active":"Set Active",async()=> { if(selected)return;if(global==null)throw new Exception("Passwall global configuration is missing.");await Command("uci set "+Quote(global+".node="+id)+" && uci commit passwall2 && /etc/init.d/passwall2 restart");await Refresh(); },true,id);
        }
        if(Nodes.Children.Count==0) Empty(Nodes,"No Passwall 2 nodes configured.");
        RenderSubscriptions(data);Tunnels.Children.Clear();
        foreach(var pair in data.Where(x=>x.Key.StartsWith("network.") && x.Key.EndsWith(".proto") && x.Value=="wireguard"))
        {
            var id=pair.Key[8..^6];if(!Regex.IsMatch(id,@"^[A-Za-z0-9_]+$"))continue;
            var state=await Command("ubus call "+Quote("network.interface."+id)+" status 2>/dev/null || printf '{\"up\":false}'"); using var json=JsonDocument.Parse(state);var up=json.RootElement.TryGetProperty("up",out var u)&&u.GetBoolean();
            var disabled=data.GetValueOrDefault("network."+id+".disabled")=="1";
            AddRow(Tunnels,"◇",id,disabled?"Disabled · ready to connect":"",up?"Connected":"Disconnected",up,up?"Disconnect":"Connect",()=>ControlWireGuard(id,up),false);
        }
        if(Tunnels.Children.Count==0) Empty(Tunnels,"No WireGuard interfaces configured.");Status.Text="Updated "+DateTime.Now.ToString("HH:mm:ss")+" · SSH connected";
    }
    void AddRow(StackPanel panel,string icon,string name,string subtitle,string state,bool on,string action,Func<Task> callback,bool menu,string nodeId="")
    {
        var grid=new Grid();
        grid.ColumnDefinitions.Add(new(){Width=new GridLength(46)});
        grid.ColumnDefinitions.Add(new(){Width=new GridLength(1,GridUnitType.Star)});
        grid.ColumnDefinitions.Add(new(){Width=GridLength.Auto});
        if(menu)grid.ColumnDefinitions.Add(new(){Width=new GridLength(25)});
        var iconKey=menu?"ServerIcon":icon=="⌂"?"HomeIcon":icon=="♧"?"GameIcon":"ShieldIcon";
        grid.Children.Add(new Border {
            Width=34,Height=36,CornerRadius=new CornerRadius(10),HorizontalAlignment=HorizontalAlignment.Left,
            Background=Brush(on?"#203B30":"#1B282B"),BorderBrush=Brush(on?"#375D48":"#2B3B3A"),BorderThickness=new Thickness(1),
            Child=new Image{Source=(ImageSource)FindResource(iconKey),Width=18,Height=19}
        });
        var copy=new StackPanel { VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,10,0) };
        Grid.SetColumn(copy,1);grid.Children.Add(copy);
        copy.Children.Add(new TextBlock {Text=name,FontSize=14,FontWeight=FontWeights.SemiBold,TextTrimming=TextTrimming.CharacterEllipsis,ToolTip=name});
        var details = new WrapPanel {Margin=new Thickness(0,6,0,0)};
        var statusColor=on?"#85E2B0":state=="Disconnected"?"#EA8A93":"#96A7AC";
        var statusStack = new StackPanel {Orientation=Orientation.Horizontal};
        statusStack.Children.Add(new System.Windows.Shapes.Ellipse{Width=5,Height=5,Fill=Brush(statusColor),VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,5,0)});
        statusStack.Children.Add(new TextBlock{Text=state,FontSize=10,Foreground=Brush(statusColor)});
        details.Children.Add(new Border{Child=statusStack,CornerRadius=new CornerRadius(6),Background=Brush(on?"#203F2F":"#1D292C"),Padding=new Thickness(6,3,6,3),Margin=new Thickness(0,0,7,0)});
        if(subtitle!="")details.Children.Add(new TextBlock{Text=subtitle,FontSize=10,Foreground=Brush("#8D9F9D"),VerticalAlignment=VerticalAlignment.Center,TextTrimming=TextTrimming.CharacterEllipsis,ToolTip=subtitle,MaxWidth=140});
        copy.Children.Add(details);
        var button=new Button {Content=action=="Active"?"✓  Active":action,FontSize=11,Padding=new Thickness(12,9,12,9),MinWidth=84,VerticalAlignment=VerticalAlignment.Center,Background=Brush(on?"#203D2F":"#1A272A"),BorderBrush=Brush(on?"#3B664A":"#354542"),Foreground=Brush(on?"#9FE3BC":"#D2E1DB")};
        Grid.SetColumn(button,2);grid.Children.Add(button);button.Click+=async(_,_)=>await Run(callback);
        if(menu)
        {
            var dots=new Button {Content="⋮",FontSize=19,Padding=new Thickness(3,6,3,6),Style=(Style)FindResource("QuietButton"),Margin=new Thickness(4,0,0,0),VerticalAlignment=VerticalAlignment.Center,ToolTip="More options"};
            System.Windows.Automation.AutomationProperties.SetName(dots,"More options for "+name);
            Grid.SetColumn(dots,3);grid.Children.Add(dots);
            var context=new ContextMenu{Background=Brush("#172423"),Foreground=Brush("#D5E7DE"),BorderBrush=Brush("#3B574A")};
            var item=new MenuItem{Header="Open in LuCI"};item.Click+=(_,_)=>OpenLuci();context.Items.Add(item);
            var delete=new MenuItem{Header="Delete config",Foreground=Brush("#EB7D88")};delete.Click+=async(_,_)=>{if(MessageBox.Show(this,"Delete “"+name+"”?\n\nSubscription nodes may return after an update. Active or referenced nodes must be unlinked first.","Delete configuration",MessageBoxButton.YesNo,MessageBoxImage.Warning)==MessageBoxResult.Yes)await ImportNodes("delete","","",nodeId);};context.Items.Add(delete);
            dots.Click+=(_,_)=> { context.PlacementTarget=dots;context.IsOpen=true; };
        }
        var card=new Border {Child=grid,Padding=new Thickness(12,12,12,12),Margin=new Thickness(0,0,0,9),CornerRadius=new CornerRadius(12),Background=Brush(on?"#152C24":"#131E22"),BorderBrush=Brush(on?"#457A56":"#2A3936"),BorderThickness=new Thickness(1)};
        card.MouseEnter+=(_,_)=>card.BorderBrush=Brush(on?"#69A979":"#486055");
        card.MouseLeave+=(_,_)=>card.BorderBrush=Brush(on?"#457A56":"#2A3936");
        panel.Children.Add(card);
    }
    async void EditHostClick(object sender,RoutedEventArgs e)
    {
        if(client?.IsConnected==true) await ConnectClickForEdit();
        Host.IsReadOnly=false;Host.Focus();Host.SelectAll();
    }
    async Task ConnectClickForEdit()
    {
        await Run(()=> {client?.Dispose();client=null;Connection.Content="Connect";LoginPanel.Visibility=Visibility.Visible;Host.IsReadOnly=false;Toggle.IsEnabled=false;Empty(Nodes,"Connect to load configurations.");Empty(Tunnels,"Connect to load tunnels.");Status.Text="Enter a router address to connect.";return Task.CompletedTask;});
    }
    void OpenLuci() { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("http://"+Host.Text.Trim()+"/cgi-bin/luci/admin/services/passwall2"){UseShellExecute=true}); }
    async void ToggleClick(object s,RoutedEventArgs e)=>await Run(async()=> { await Command("uci set "+Quote(Toggle.Tag+".enabled="+(enabled?"0":"1"))+" && uci commit passwall2 && /etc/init.d/passwall2 "+(enabled?"stop":"restart"));await Refresh(); });
    async void RefreshClick(object s,RoutedEventArgs e)=>await Run(async()=> {await Refresh();});
    void PassTabClick(object s,RoutedEventArgs e) {HideTools();WirePanel.Visibility=Visibility.Collapsed;PassPanel.Visibility=Visibility.Visible;PassTab.Background=Brush("#214333");PassTab.BorderBrush=Brush("#416B50");WireTab.Background=Brush("#00101A1C");WireTab.BorderBrush=Brush("#00101A1C");ContentScroll.ScrollToTop();}
    void WireTabClick(object s,RoutedEventArgs e) {HideTools();PassPanel.Visibility=Visibility.Collapsed;PassTab.Background=Brush("#00101A1C");PassTab.BorderBrush=Brush("#00101A1C");WireTab.Background=Brush("#214333");WireTab.BorderBrush=Brush("#416B50");ContentScroll.ScrollToTop();}
}









