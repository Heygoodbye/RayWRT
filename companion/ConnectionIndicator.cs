using System.ComponentModel;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;

namespace RayWRT.Companion;
public partial class MainWindow
{
    readonly DispatcherTimer connectionWatch = new(){Interval=TimeSpan.FromSeconds(2)};
    bool? displayedConnected;
    bool displayedConnecting;
    void InitializeConnectionIndicator()
    {
        SetConnectionIndicator(false);
        Loaded+=(_,_)=> {ApplyHeartbeatPreference();connectionWatch.Start();};
        connectionWatch.Tick+=(_,_)=> {if(!busy)UpdateConnectionIndicator();};
        SystemParameters.StaticPropertyChanged+=HeartbeatPreferenceChanged;
        Closed+=(_,_)=>
        {
            connectionWatch.Stop();
            SystemParameters.StaticPropertyChanged-=HeartbeatPreferenceChanged;
            ConnectionHalo.BeginAnimation(OpacityProperty,null);
        };
    }
    void HeartbeatPreferenceChanged(object? sender,PropertyChangedEventArgs e)
    {
        if(e.PropertyName==nameof(SystemParameters.ClientAreaAnimation)) Dispatcher.BeginInvoke(ApplyHeartbeatPreference);
    }
    void ApplyHeartbeatPreference()
    {
        ConnectionHalo.BeginAnimation(OpacityProperty,null);
        ConnectionHalo.Opacity=0.05;
        if(!SystemParameters.ClientAreaAnimation)return;
        var heartbeat=new DoubleAnimationUsingKeyFrames {Duration=TimeSpan.FromSeconds(2.8),RepeatBehavior=RepeatBehavior.Forever};
        heartbeat.KeyFrames.Add(new LinearDoubleKeyFrame(0.04,KeyTime.FromTimeSpan(TimeSpan.Zero)));
        heartbeat.KeyFrames.Add(new EasingDoubleKeyFrame(0.16,KeyTime.FromTimeSpan(TimeSpan.FromSeconds(0.18)),new SineEase{EasingMode=EasingMode.EaseInOut}));
        heartbeat.KeyFrames.Add(new EasingDoubleKeyFrame(0.04,KeyTime.FromTimeSpan(TimeSpan.FromSeconds(0.4)),new SineEase{EasingMode=EasingMode.EaseInOut}));
        heartbeat.KeyFrames.Add(new EasingDoubleKeyFrame(0.11,KeyTime.FromTimeSpan(TimeSpan.FromSeconds(0.58)),new SineEase{EasingMode=EasingMode.EaseInOut}));
        heartbeat.KeyFrames.Add(new EasingDoubleKeyFrame(0.03,KeyTime.FromTimeSpan(TimeSpan.FromSeconds(0.86)),new SineEase{EasingMode=EasingMode.EaseInOut}));
        heartbeat.KeyFrames.Add(new LinearDoubleKeyFrame(0.04,KeyTime.FromTimeSpan(TimeSpan.FromSeconds(2.8))));
        Timeline.SetDesiredFrameRate(heartbeat,24);
        ConnectionHalo.BeginAnimation(OpacityProperty,heartbeat);
    }
    void UpdateConnectionIndicator()
    {
        var connected=client?.IsConnected==true;AddNode.IsEnabled=connected;ImportWireGuard.IsEnabled=connected; if(!connected)Subscriptions.Children.Clear();
        if(!connected && displayedConnected==true && client!=null)
        {
            Connection.Content="Reconnect";Toggle.IsEnabled=false;
            LoginPanel.Visibility=Visibility.Visible;Host.IsReadOnly=false;
            Status.Text="Router disconnected. Connect again to continue.";
        }
        SetConnectionIndicator(connected);
    }
    void SetConnectionIndicator(bool connected,bool connecting=false)
    {
        if(displayedConnected==connected && displayedConnecting==connecting)return;
        displayedConnected=connected;displayedConnecting=connecting;
        var color=connected?"#75DDA9":"#EB7D88";
        ConnectionDot.Fill=Brush(color);ConnectionHalo.Fill=Brush(color);
        RouterStateText.Text=connected?"Connected":connecting?"Connecting…":"Disconnected";
        RouterStateText.Foreground=Brush(connected?"#9BCDB4":"#9EAAA6");
        RouterStateBadge.ToolTip=connected?"SSH connected to your router":connecting?"Establishing SSH connection":"SSH disconnected";
        System.Windows.Automation.AutomationProperties.SetName(RouterStateBadge,"Router "+RouterStateText.Text.ToLowerInvariant());
    }
}

