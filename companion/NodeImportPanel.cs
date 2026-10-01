using System.IO;
using System.Windows;
using System.Windows.Controls;
namespace RayWRT.Companion;
public partial class MainWindow
{
 async void AddNodeClick(object sender,RoutedEventArgs e)
 {
  if(busy)return;
  if(client?.IsConnected!=true){Status.Text="Connect to your router first.";return;}
  var panel=new StackPanel{Margin=new Thickness(24)};panel.Resources.MergedDictionaries.Add(Resources);
  panel.Children.Add(new TextBlock{Text="Add to Passwall 2",FontSize=21,FontWeight=FontWeights.SemiBold,Margin=new Thickness(0,0,0,18)});
  var kind=new ComboBox{Style=(Style)FindResource("WifiSelector"),ItemsSource=new[]{"Node link","Subscription URL"},SelectedIndex=0,Margin=new Thickness(0,0,0,16)};panel.Children.Add(kind);
  panel.Children.Add(new TextBlock{Text="Link",Margin=new Thickness(0,0,0,7)});
  var link=new TextBox{MinHeight=42,MaxLength=16384};panel.Children.Add(link);
  panel.Children.Add(new TextBlock{Text="Name (optional)",Margin=new Thickness(0,16,0,7)});
  var name=new TextBox{MinHeight=42,MaxLength=80};panel.Children.Add(name);
  panel.Children.Add(new TextBlock{Text="Imports use your router’s Passwall 2 parser. Subscriptions are saved for manual updates.",TextWrapping=TextWrapping.Wrap,Foreground=Brush("#91A69E"),Margin=new Thickness(0,15,0,12)});
  var error=new TextBlock{Foreground=Brush("#EB7D88"),TextWrapping=TextWrapping.Wrap};panel.Children.Add(error);
  var buttons=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Right,Margin=new Thickness(0,18,0,0)};
  var cancel=new Button{Content="Cancel",MinWidth=96,Height=42,FontSize=13,Margin=new Thickness(0,0,10,0),Background=Brush("#182423"),BorderBrush=Brush("#354942")};var add=new Button{Content="＋ Add",MinWidth=106,Height=42,FontSize=13,Background=Brush("#214D37"),BorderBrush=Brush("#428963"),Foreground=Brush("#B5F1CE"),IsDefault=true};buttons.Children.Add(cancel);buttons.Children.Add(add);panel.Children.Add(buttons);
  var dialog=new Window{Owner=this,Title="Add node or subscription",Width=420,SizeToContent=SizeToContent.Height,ResizeMode=ResizeMode.NoResize,WindowStartupLocation=WindowStartupLocation.CenterOwner,Background=Brush("#121E21"),Foreground=Brush("#EDF3F2"),WindowStyle=WindowStyle.None,AllowsTransparency=true,Content=new Border{CornerRadius=new CornerRadius(18),Background=Brush("#121E21"),BorderBrush=Brush("#354542"),BorderThickness=new Thickness(1),Child=panel}};dialog.Background=System.Windows.Media.Brushes.Transparent;
  if(Environment.GetCommandLineArgs().Contains("--add-dialog-capture"))dialog.Loaded+=(_,_)=>{dialog.UpdateLayout();var bitmap=new System.Windows.Media.Imaging.RenderTargetBitmap((int)dialog.ActualWidth,(int)dialog.ActualHeight,96,96,System.Windows.Media.PixelFormats.Pbgra32);bitmap.Render(dialog);var encoder=new System.Windows.Media.Imaging.PngBitmapEncoder();encoder.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(bitmap));using var file=File.Create(Path.Combine(AppContext.BaseDirectory,"add-dialog.png"));encoder.Save(file);dialog.Dispatcher.BeginInvoke(()=>dialog.Close());};
  string mode="",value="",label="";
  cancel.Click+=(_,_)=>dialog.Close();
  add.Click+=(_,_)=> {try{mode=kind.SelectedIndex==0?"node":"subscription";value=link.Text.Trim();label=name.Text.Trim();NodeImport.Validate(mode,value,label);dialog.DialogResult=true;}catch(Exception ex){error.Text=ex.Message;}};
  if(dialog.ShowDialog()==true)await ImportNodes(mode,value,label);
 }
 async Task ImportNodes(string mode,string link,string name,string id="")=>await Run(()=>ExecuteImport(mode,link,name,id));
 async Task ExecuteImport(string mode,string link,string name,string id="")
 {
  Status.Text=mode=="update"?"Updating subscription…":"Importing nodes…";
  using var stream=typeof(MainWindow).Assembly.GetManifestResourceStream("RayWRT.NodeImport")!;using var reader=new StreamReader(stream);
  var result=await Command(NodeImport.Command(await reader.ReadToEndAsync(),mode,link,name,id),240);
  await Refresh();Status.Text=result.Trim();
 }
 void RenderSubscriptions(Dictionary<string,string> data)
 {
  Subscriptions.Children.Clear();
  foreach(var pair in data.Where(x=>x.Key.StartsWith("passwall2.")&&x.Value=="subscribe_list"))
  {
   if(Subscriptions.Children.Count==0)Subscriptions.Children.Add(new TextBlock{Text="SUBSCRIPTIONS",FontSize=10,Foreground=Brush("#91A69E"),Margin=new Thickness(0,16,0,12)});
   var id=pair.Key[10..];var name=data.GetValueOrDefault(pair.Key+".remark",id);
   AddRow(Subscriptions,"▤",name,"Manual updates","Saved",false,"Update",()=>ExecuteImport("update","","",id),false);
  }
 }
}




