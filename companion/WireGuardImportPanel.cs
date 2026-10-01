using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
namespace RayWRT.Companion;
public partial class MainWindow
{
 async void ImportWireGuardClick(object sender,RoutedEventArgs e)
 {
  if(busy||client?.IsConnected!=true)return;
  var panel=new StackPanel{Margin=new Thickness(24)};panel.Resources.MergedDictionaries.Add(Resources);
  panel.Children.Add(new TextBlock{Text="Import WireGuard",FontSize=21,FontWeight=FontWeights.SemiBold,Margin=new Thickness(0,0,0,16)});
  panel.Children.Add(new TextBlock{Text="Interface name",Margin=new Thickness(0,0,0,7)});
  var name=new TextBox{Text="wg_import",MaxLength=15,MinHeight=40};panel.Children.Add(name);
  panel.Children.Add(new TextBlock{Text="WireGuard .conf",Margin=new Thickness(0,16,0,7)});
  var config=new TextBox{AcceptsReturn=true,TextWrapping=TextWrapping.NoWrap,VerticalScrollBarVisibility=ScrollBarVisibility.Auto,HorizontalScrollBarVisibility=ScrollBarVisibility.Auto,Height=180,FontFamily=new FontFamily("Consolas"),FontSize=12};panel.Children.Add(config);
  var browse=new Button{Content="Choose .conf file",Margin=new Thickness(0,10,0,0),HorizontalAlignment=HorizontalAlignment.Left};panel.Children.Add(browse);
  browse.Click+=(_,_)=>{var picker=new OpenFileDialog{Filter="WireGuard config (*.conf)|*.conf|All files (*.*)|*.*",CheckFileExists=true};if(picker.ShowDialog(this)==true){if(new FileInfo(picker.FileName).Length>65536){MessageBox.Show(this,"File exceeds 64 KB.");return;}config.Text=File.ReadAllText(picker.FileName);name.Text=System.Text.RegularExpressions.Regex.Replace(Path.GetFileNameWithoutExtension(picker.FileName).ToLowerInvariant(),"[^a-z0-9_]","_");}};
  panel.Children.Add(new TextBlock{Text="Imports into the WAN firewall zone. The new interface stays disconnected until you press Connect.",Foreground=Brush("#91A69E"),TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,14,0,0)});
  var error=new TextBlock{Foreground=Brush("#EB7D88"),TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,10,0,0)};panel.Children.Add(error);
  var actions=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Right,Margin=new Thickness(0,18,0,0)};
  var cancel=new Button{Content="Cancel",MinWidth=95,Height=42,Margin=new Thickness(0,0,10,0)};var add=new Button{Content="Import",MinWidth=110,Height=42,IsDefault=true,Background=Brush("#214D37"),BorderBrush=Brush("#428963")};actions.Children.Add(cancel);actions.Children.Add(add);panel.Children.Add(actions);
  var dialog=new Window{Owner=this,Title="Import WireGuard",Width=440,SizeToContent=SizeToContent.Height,ResizeMode=ResizeMode.NoResize,WindowStartupLocation=WindowStartupLocation.CenterOwner,WindowStyle=WindowStyle.None,AllowsTransparency=true,Background=Brush("#00121E21"),Foreground=Brush("#EDF3F2"),Content=new Border{CornerRadius=new CornerRadius(18),Background=Brush("#121E21"),BorderBrush=Brush("#354542"),BorderThickness=new Thickness(1),Child=panel}};
  string chosenName="",chosenConfig="";
  cancel.Click+=(_,_)=>dialog.Close();
  add.Click+=(_,_)=>{try{chosenName=name.Text.Trim();chosenConfig=config.Text;WireGuardImport.Command(chosenName,chosenConfig);dialog.DialogResult=true;}catch(Exception ex){error.Text=ex.Message;}};
  if(dialog.ShowDialog()!=true)return;
  await Run(async()=>{Status.Text="Importing WireGuard configuration…";var result=await Command(WireGuardImport.Command(chosenName,chosenConfig),60);await Refresh();Status.Text=result.Trim();});
 }
}
