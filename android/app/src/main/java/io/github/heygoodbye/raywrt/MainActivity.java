package io.github.heygoodbye.raywrt;

import android.animation.ValueAnimator;
import android.app.*;
import android.content.*;
import android.content.res.Configuration;
import android.graphics.*;
import android.graphics.drawable.*;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.text.*;
import android.text.method.PasswordTransformationMethod;
import android.util.TypedValue;
import android.view.*;
import android.view.inputmethod.InputMethodManager;
import android.widget.*;
import org.json.JSONObject;
import java.util.*;
import java.util.concurrent.*;

public final class MainActivity extends Activity {
    private static final int BG=0xff0b1117,PANEL=0xff121e21,TEXT=0xffedf3f2,MUTED=0xff91a69e,GREEN=0xff75dda9,RED=0xffeb7d88;
    private final Handler main=new Handler(Looper.getMainLooper());
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private final RouterClient router=new RouterClient();
    private boolean busy=false,wireFocused=false,wasConnected=false;
    private EditText host,user,password;
    private LinearLayout root,body,login,nodes,tunnels,passPanel,wirePanel;
    private TextView status,stateLabel;
    private Button connectButton,refreshButton,passTab,wireTab,addNodeButton,importWireButton;
    private EditText wireConfigField,wireNameField;
    private Switch serviceSwitch;
    private ToolsPanel toolsPanel; private Button routerTab;
    private ScrollView scroll;
    private PulseDot pulse;
    private RouterModel model;
    private String connectedHost="";
    private SharedPreferences preferences;
    private final Runnable watch=new Runnable(){public void run(){if(!busy)syncConnection();main.postDelayed(this,2000);}};
    private final List<View> actions=new ArrayList<>();

    @Override public void onCreate(Bundle state){
        super.onCreate(state);
        preferences=getSharedPreferences("router",MODE_PRIVATE);
        if(Build.VERSION.SDK_INT>=30)getWindow().setDecorFitsSystemWindows(false);
        else getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        getWindow().setStatusBarColor(Color.TRANSPARENT);getWindow().setNavigationBarColor(BG);
        build();
    }
    private int dp(float value){return Math.round(value*getResources().getDisplayMetrics().density);}
    private TextView text(String value,float size,int color){
        TextView view=new TextView(this);view.setText(value);view.setTextSize(size);view.setTextColor(color);view.setIncludeFontPadding(false);return view;
    }
    private LinearLayout column(){LinearLayout view=new LinearLayout(this);view.setOrientation(LinearLayout.VERTICAL);return view;}
    private LinearLayout row(){LinearLayout view=new LinearLayout(this);view.setOrientation(LinearLayout.HORIZONTAL);view.setGravity(Gravity.CENTER_VERTICAL);return view;}
    private GradientDrawable shape(int fill,int line,float radius){GradientDrawable drawable=new GradientDrawable();drawable.setColor(fill);drawable.setCornerRadius(dp(radius));if(line!=0)drawable.setStroke(dp(1),line);return drawable;}
    private RippleDrawable ripple(int fill,int line,float radius){return new RippleDrawable(android.content.res.ColorStateList.valueOf(0x2465e5b0),shape(fill,line,radius),shape(Color.WHITE,0,radius));}
    private Button button(String title,boolean accent){
        Button button=new Button(this);button.setText(title);button.setTextSize(12);button.setTextColor(accent?0xffa3e4bd:0xffd6e5df);button.setAllCaps(false);button.setMinHeight(dp(44));button.setMinimumHeight(dp(44));button.setMinWidth(0);button.setMinimumWidth(0);button.setPadding(dp(13),dp(8),dp(13),dp(8));button.setBackground(ripple(accent?0xff203d2f:0xff1a272a,accent?0xff3b664a:0xff354542,10));return button;
    }
    private void centerTabIcon(Button tab){
        tab.setGravity(Gravity.CENTER);tab.setSingleLine(true);tab.setCompoundDrawablePadding(dp(6));
        tab.addOnLayoutChangeListener((v,l,t,r,b,ol,ot,or,ob)->{
            Drawable icon=tab.getCompoundDrawables()[0];if(icon==null)return;
            int groupWidth=icon.getBounds().width()+tab.getCompoundDrawablePadding()+(int)Math.ceil(tab.getPaint().measureText(tab.getText().toString()));
            int inset=Math.max(dp(4),(r-l-groupWidth)/2);
            if(tab.getPaddingLeft()!=inset||tab.getPaddingRight()!=inset)tab.setPadding(inset,0,inset,0);
        });
    }
    private EditText field(String value,boolean secret){
        EditText edit=new EditText(this);edit.setText(value);edit.setTextColor(TEXT);edit.setTextSize(14);edit.setSingleLine(true);edit.setPadding(dp(12),dp(12),dp(12),dp(12));edit.setBackground(shape(0xff111c1e,0xff2c3d3e,10));edit.setMinHeight(dp(48));edit.setSaveEnabled(!secret);edit.setSelectAllOnFocus(false);
        if(secret){edit.setInputType(android.text.InputType.TYPE_CLASS_TEXT|android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD);edit.setTransformationMethod(PasswordTransformationMethod.getInstance());edit.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS);}
        else edit.setInputType(android.text.InputType.TYPE_CLASS_TEXT|android.text.InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        edit.setOnFocusChangeListener((v,focused)->edit.setBackground(shape(0xff111c1e,focused?0xff65e5b0:0xff2c3d3e,10)));
        return edit;
    }
    private LinearLayout card(){LinearLayout view=column();view.setPadding(dp(16),dp(16),dp(16),dp(16));view.setBackground(shape(PANEL,0xff283735,17));return view;}
    private void space(LinearLayout parent,int amount){View spacer=new View(this);parent.addView(spacer,new LinearLayout.LayoutParams(1,dp(amount)));}
    private void section(LinearLayout view,int top){LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,-2);p.topMargin=dp(top);body.addView(view,p);}
    private void build(){
        root=column();root.setBackground(new GradientDrawable(GradientDrawable.Orientation.TL_BR,new int[]{0xff163329,BG,BG}));
        root.setOnApplyWindowInsetsListener((v,insets)->{
            if(Build.VERSION.SDK_INT>=30){android.graphics.Insets bars=insets.getInsets(WindowInsets.Type.systemBars()|WindowInsets.Type.displayCutout());android.graphics.Insets ime=insets.getInsets(WindowInsets.Type.ime());root.setPadding(bars.left,bars.top,bars.right,Math.max(bars.bottom,ime.bottom));}
            else root.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());
            return insets;
        });
        setContentView(root);
        LinearLayout header=row();header.setPadding(dp(20),dp(18),dp(20),dp(17));
        ImageView logo=new ImageView(this);logo.setImageResource(R.drawable.raywrt_logo);logo.setContentDescription("RayWRT logo");header.addView(logo,new LinearLayout.LayoutParams(dp(37),dp(37)));
        LinearLayout title=column();LinearLayout.LayoutParams titleParams=new LinearLayout.LayoutParams(0,-2,1);titleParams.leftMargin=dp(11);header.addView(title,titleParams);
        TextView heading=text("RayWRT",20,TEXT);heading.setTypeface(null,android.graphics.Typeface.BOLD);heading.setSingleLine(true);heading.setEllipsize(TextUtils.TruncateAt.END);title.addView(heading);
        TextView caption=text("Router Configure",9,0xff77998b);caption.setLetterSpacing(.10f);LinearLayout.LayoutParams cap=new LinearLayout.LayoutParams(-2,-2);cap.topMargin=dp(5);title.addView(caption,cap);root.addView(header);
        scroll=new ScrollView(this);scroll.setFillViewport(false);scroll.setVerticalScrollBarEnabled(false);scroll.setHorizontalScrollBarEnabled(false);scroll.setClipToPadding(false);scroll.setOverScrollMode(View.OVER_SCROLL_IF_CONTENT_SCROLLS);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        FrameLayout bodyFrame=new FrameLayout(this);scroll.addView(bodyFrame,new ScrollView.LayoutParams(-1,-2));body=column();body.setPadding(dp(18),0,dp(18),dp(14));FrameLayout.LayoutParams bodyParams=new FrameLayout.LayoutParams(Math.min(getResources().getDisplayMetrics().widthPixels,dp(620)),-2,Gravity.CENTER_HORIZONTAL);bodyFrame.addView(body,bodyParams);
        bodyFrame.addOnLayoutChangeListener((v,l,t,r,b,ol,ot,or,ob)->{int width=Math.min(r-l,dp(620));if(body.getLayoutParams().width!=width){body.getLayoutParams().width=width;body.requestLayout();}});
        LinearLayout connection=card();section(connection,0);
        LinearLayout ipLabel=row();TextView ip=text("Router IP",11,MUTED);ipLabel.addView(ip,new LinearLayout.LayoutParams(0,-2,1));pulse=new PulseDot();ipLabel.addView(pulse,new LinearLayout.LayoutParams(dp(19),dp(19)));stateLabel=text("Disconnected",10,MUTED);ipLabel.addView(stateLabel);connection.addView(ipLabel);
        space(connection,8);LinearLayout ipRow=row();Icon routerIcon=new Icon("router",MUTED);LinearLayout.LayoutParams ri=new LinearLayout.LayoutParams(dp(26),dp(26));ri.rightMargin=dp(11);ipRow.addView(routerIcon,ri);
        host=field(preferences.getString("host","192.168.1.1"),false);host.setContentDescription("Router IP or hostname");ipRow.addView(host,new LinearLayout.LayoutParams(0,dp(48),1));
        connectButton=button("Connect",true);LinearLayout.LayoutParams cp=new LinearLayout.LayoutParams(dp(98),dp(48));cp.leftMargin=dp(9);ipRow.addView(connectButton,cp);connectButton.setOnClickListener(v->connect());connection.addView(ipRow);
        login=column();space(login,16);LinearLayout credentials=row();LinearLayout userCol=column(),passCol=column();userCol.addView(text("SSH username",11,MUTED));passCol.addView(text("SSH password",11,MUTED));space(userCol,7);space(passCol,7);user=field(preferences.getString("user","root"),false);password=field("",true);user.setContentDescription("SSH username");password.setContentDescription("SSH password");userCol.addView(user,new LinearLayout.LayoutParams(-1,dp(48)));passCol.addView(password,new LinearLayout.LayoutParams(-1,dp(48)));LinearLayout.LayoutParams up=new LinearLayout.LayoutParams(0,-2,1);up.rightMargin=dp(6);credentials.addView(userCol,up);LinearLayout.LayoutParams pp=new LinearLayout.LayoutParams(0,-2,1);pp.leftMargin=dp(6);credentials.addView(passCol,pp);login.addView(credentials);space(login,10);login.addView(text("Your password is never saved.",11,0xff738b83));connection.addView(login);
        LinearLayout tabs=row();tabs.setPadding(dp(4),dp(4),dp(4),dp(4));tabs.setBackground(shape(0xff101a1c,0xff283735,13));passTab=button("Passwall 2",true);wireTab=button("WireGuard",false);passTab.setCompoundDrawablesWithIntrinsicBounds(getDrawable(R.drawable.globe_icon),null,null,null);wireTab.setCompoundDrawablesWithIntrinsicBounds(getDrawable(R.drawable.shield_icon),null,null,null);for(Button tab:new Button[]{passTab,wireTab}){tab.setCompoundDrawablePadding(dp(5));tab.setPadding(dp(7),0,dp(7),0);tab.setTextSize(11);}tabs.addView(passTab,new LinearLayout.LayoutParams(0,dp(45),1));LinearLayout.LayoutParams wt=new LinearLayout.LayoutParams(0,dp(45),1);wt.leftMargin=dp(4);tabs.addView(wireTab,wt);routerTab=button("Router",false);routerTab.setCompoundDrawablesWithIntrinsicBounds(getDrawable(R.drawable.modem_icon),null,null,null);routerTab.setCompoundDrawablePadding(dp(5));routerTab.setPadding(dp(8),dp(8),dp(8),dp(8));tabs.addView(routerTab,new LinearLayout.LayoutParams(0,dp(45),1));for(Button tab:new Button[]{passTab,wireTab,routerTab})centerTabIcon(tab);routerTab.setOnClickListener(v->selectTools());section(tabs,16);passTab.setOnClickListener(v->selectTab(false));wireTab.setOnClickListener(v->selectTab(true));
        passPanel=card();section(passPanel,16);LinearLayout passHeading=sectionHeading("globe","Passwall 2","Manage your Passwall 2 configurations");addNodeButton=button("＋ Add",true);addNodeButton.setTextSize(11);addNodeButton.setPadding(dp(8),0,dp(8),0);addNodeButton.setContentDescription("Add node or subscription");addNodeButton.setOnClickListener(v->showAddNode());passHeading.addView(addNodeButton,new LinearLayout.LayoutParams(-2,dp(40)));serviceSwitch=new Switch(this);serviceSwitch.setText("");serviceSwitch.setContentDescription("Enable or disable Passwall 2");serviceSwitch.setShowText(false);serviceSwitch.setThumbTintList(android.content.res.ColorStateList.valueOf(0xffdaf9e9));serviceSwitch.setTrackTintList(new android.content.res.ColorStateList(new int[][]{new int[]{android.R.attr.state_checked},new int[]{}},new int[]{0xff277553,0xff344344}));serviceSwitch.setOnClickListener(v->{boolean requested=serviceSwitch.isChecked();serviceSwitch.setChecked(model!=null && model.enabled);operate(()->{if(model==null||model.global==null)throw new Exception("No Passwall 2 global configuration found.");router.command("uci set "+RouterModel.quote(model.global+".enabled="+(requested?"1":"0"))+" && uci commit passwall2 && /etc/init.d/passwall2 "+(requested?"restart":"stop"));return load();});});passHeading.addView(serviceSwitch,new LinearLayout.LayoutParams(dp(47),dp(44)));serviceSwitch.setEnabled(false);serviceSwitch.setAlpha(.45f);passPanel.addView(passHeading);space(passPanel,18);nodes=column();passPanel.addView(nodes);
        wirePanel=card();section(wirePanel,16);LinearLayout wireHeading=sectionHeading("shield","WireGuard","Manage your WireGuard tunnels");importWireButton=button("＋ Import",true);importWireButton.setTextSize(11);importWireButton.setContentDescription("Import WireGuard configuration");importWireButton.setOnClickListener(v->showWireGuardImport());wireHeading.addView(importWireButton,new LinearLayout.LayoutParams(-2,dp(40)));wirePanel.addView(wireHeading);space(wirePanel,18);tunnels=column();wirePanel.addView(tunnels);
        empty(nodes,"Connect to load your Passwall configurations.");empty(tunnels,"Connect to load your WireGuard tunnels.");
        toolsPanel=new ToolsPanel(this,new ToolsPanel.Host(){
            public boolean connected(){return router.connected();}
            public void run(String command,String message,Runnable after){runTool(command,message,after);}
            public void ping(){runPing();}
        });section(toolsPanel,16);toolsPanel.setVisibility(View.GONE);
        LinearLayout footer=column();footer.setPadding(dp(20),dp(9),dp(20),dp(12));footer.setBackgroundColor(0xff0c1418);refreshButton=button("↻  Refresh",false);refreshButton.setBackground(ripple(Color.TRANSPARENT,0,8));refreshButton.setMinHeight(dp(36));refreshButton.setMinimumHeight(dp(36));refreshButton.setPadding(0,0,dp(10),0);footer.addView(refreshButton,new LinearLayout.LayoutParams(-2,dp(36)));refreshButton.setOnClickListener(v->operate(()->load()));status=text("Enter your router login.",13,0xffa4bbb0);status.setMaxLines(3);status.setEllipsize(TextUtils.TruncateAt.END);status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);footer.addView(status);space(footer,9);
        LinearLayout credit=row();TextView author=text("Made by Heygoodbye ↗",11,0xff9bcdb4);author.setPadding(0,dp(7),0,dp(7));author.setBackground(ripple(Color.TRANSPARENT,0,6));author.setContentDescription("Open Heygoodbye on GitHub");author.setOnClickListener(v->openUrl("https://github.com/Heygoodbye"));credit.addView(author,new LinearLayout.LayoutParams(0,-2,1));credit.addView(text("v1",10,0xff789087));footer.addView(credit);root.addView(footer);
        actions.add(refreshButton);actions.add(connectButton);actions.add(host);actions.add(user);actions.add(password);
        selectTab(false);syncConnection();root.requestApplyInsets();
    }
    private LinearLayout sectionHeading(String glyph,String title,String description){
        LinearLayout heading=row();FrameLayout iconBox=new FrameLayout(this);iconBox.setBackground(shape(0xff1c322b,0,10));Icon icon=new Icon(glyph,glyph.equals("globe")?GREEN:MUTED);FrameLayout.LayoutParams iconParams=new FrameLayout.LayoutParams(dp(19),dp(19),Gravity.CENTER);iconBox.addView(icon,iconParams);heading.addView(iconBox,new LinearLayout.LayoutParams(dp(33),dp(33)));
        LinearLayout titles=column();LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(0,-2,1);p.leftMargin=dp(10);p.rightMargin=dp(8);heading.addView(titles,p);TextView name=text(title,19,TEXT);name.setTypeface(null,Typeface.BOLD);titles.addView(name);space(titles,6);titles.addView(text(description,11,MUTED));return heading;
    }
    private void empty(LinearLayout list,String message){list.removeAllViews();TextView view=text(message,12,MUTED);view.setPadding(0,dp(10),0,dp(12));list.addView(view);}
    private void selectTab(boolean wire){toolsPanel.setVisibility(View.GONE);wirePanel.setVisibility(wire?View.VISIBLE:View.GONE);routerTab.setBackground(ripple(Color.TRANSPARENT,0,10));wireFocused=wire;passPanel.setVisibility(wire?View.GONE:View.VISIBLE);passTab.setBackground(ripple(wire?Color.TRANSPARENT:0xff214333,wire?0:0xff416b50,10));wireTab.setBackground(ripple(wire?0xff214333:Color.TRANSPARENT,wire?0xff416b50:0,10));scroll.post(()->scroll.smoothScrollTo(0,0));}
    private void setBusy(boolean value){busy=value;if(toolsPanel!=null)toolsPanel.setBusy(value);for(View v:actions){v.setEnabled(!value);v.setAlpha(value?.5f:1f);}addNodeButton.setEnabled(!value && router.connected());importWireButton.setEnabled(!value&&router.connected());serviceSwitch.setEnabled(!value && router.connected() && model!=null && model.global!=null);serviceSwitch.setAlpha(serviceSwitch.isEnabled()?1f:.45f);}
    private interface Job{Snapshot run() throws Exception;}
    private static final class Snapshot{final RouterModel model;final List<RouterModel.Tunnel> tunnels;Snapshot(RouterModel m,List<RouterModel.Tunnel> t){model=m;tunnels=t;}}
    private Snapshot load() throws Exception{
        RouterModel m=new RouterModel(router.command("uci -q show passwall2; uci -q show network; uci -q show wireless; true"));List<RouterModel.Tunnel> ts=new ArrayList<>();
        for(String id:m.tunnelIds){JSONObject response=new JSONObject(router.command("ubus call "+RouterModel.quote("network.interface."+id)+" status 2>/dev/null || printf '{\"up\":false}'"));ts.add(new RouterModel.Tunnel(id,response.optBoolean("up",false)));}
        Map<String,Boolean> live=new HashMap<>();JSONObject wireless=new JSONObject(router.command("ubus call network.wireless status 2>/dev/null || printf '{}'"));
        for(RouterTools.Wifi w:m.wifi){JSONObject radio=wireless.optJSONObject(w.radio.substring(9));if(radio==null)continue;boolean present=false;org.json.JSONArray interfaces=radio.optJSONArray("interfaces");if(interfaces!=null)for(int i=0;i<interfaces.length();i++){JSONObject iface=interfaces.optJSONObject(i);if(iface!=null&&(w.id.substring(9).equals(iface.optString("section"))||(iface.optJSONObject("config")!=null&&w.ssid.equals(iface.optJSONObject("config").optString("ssid")))))present=true;}live.put(w.id,radio.optBoolean("up",false)&&present);}
        m.wifi.clear();m.wifi.addAll(RouterTools.runtime(RouterTools.wireless(m.raw),live));return new Snapshot(m,ts);
    }
    private void operate(Job job){
        if(busy)return;if(!router.connected()){status.setText("Connect to your router first.");syncConnection();return;}
        setBusy(true);status.setText("Updating router…");
        worker.execute(()->{try{Snapshot snapshot=job.run();main.post(()->{if(isFinishing()||isDestroyed())return;render(snapshot);status.setText("Updated · SSH connected");setBusy(false);syncConnection();});}catch(Exception ex){postError(ex);}});
    }
    private void connect(){
        if(busy)return;
        if(router.connected()){router.close();model=null;empty(nodes,"Connect to load your Passwall configurations.");empty(tunnels,"Connect to load your WireGuard tunnels.");status.setText("Disconnected.");syncConnection();return;}
        String address=host.getText().toString().trim(),username=user.getText().toString().trim(),secret=password.getText().toString();
        if(address.startsWith("[")&&address.endsWith("]"))address=address.substring(1,address.length()-1);
        if(!address.matches("[A-Za-z0-9][A-Za-z0-9.:-]*")||username.isEmpty()){status.setText("Enter a valid router address and SSH username.");return;}
        connectedHost=address;
        
        ((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(password.getWindowToken(),0);
        setBusy(true);stateLabel.setText("Connecting…");pulse.setConnected(false);status.setText("Connecting…");
        final String target=address;
        worker.execute(()->{
            try{
                router.connect(target,username,secret,new RouterClient.Trust(){
                    public String stored(String h){return preferences.getString("fingerprint:"+h,null);}
                    public void save(String h,String fp){preferences.edit().putString("fingerprint:"+h,fp).apply();}
                    public boolean confirm(String h,String fp)throws Exception{return confirmIdentity(h,fp);}
                });
                preferences.edit().putString("host",target).putString("user",username).apply();
                main.post(()->{if(isFinishing()||isDestroyed())return;password.setText("");login.setVisibility(View.GONE);connectButton.setText("Disconnect");pulse.setConnected(true);stateLabel.setText("Connected");wasConnected=true;});
                Snapshot snapshot=load();
                main.post(()->{if(isFinishing()||isDestroyed())return;render(snapshot);status.setText("Connected · Router configurations loaded");setBusy(false);syncConnection();});
            }catch(Exception ex){postError(ex);}
        });
    }
    private boolean confirmIdentity(String hostname,String fingerprint)throws Exception{
        CountDownLatch latch=new CountDownLatch(1);boolean[] accepted={false};
        main.post(()->{
            if(isFinishing()||isDestroyed()){latch.countDown();return;}
            String previous=preferences.getString("fingerprint:"+hostname,null);new AlertDialog.Builder(this).setTitle(previous==null?"Trust this router?":"Router identity changed").setMessage((previous==null?"":"Reinstalling OpenWrt can change the router identity. Verify the new fingerprint before trusting it.\n\nPrevious: "+previous+"\n\n")+hostname+"\n\n"+fingerprint+"\n\nVerify this SSH fingerprint before trusting a new router.").setPositiveButton("Trust",(dialog,which)->{accepted[0]=true;latch.countDown();}).setNegativeButton("Cancel",(dialog,which)->latch.countDown()).setOnCancelListener(dialog->latch.countDown()).show();
        });
        return latch.await(90,TimeUnit.SECONDS)&&accepted[0];
    }
    private void postError(Exception ex){main.post(()->{if(isFinishing()||isDestroyed())return;setBusy(false);syncConnection();String message=ex.getMessage();status.setText("Error: "+(message==null?ex.getClass().getSimpleName():message));});}
    private void syncConnection(){
        boolean connected=router.connected();addNodeButton.setEnabled(!busy&&connected);importWireButton.setEnabled(!busy&&connected);importWireButton.setAlpha(importWireButton.isEnabled()?1f:.45f);addNodeButton.setAlpha(addNodeButton.isEnabled()?1f:.45f);if(toolsPanel!=null)toolsPanel.setBusy(busy);pulse.setConnected(connected);stateLabel.setText(connected?"Connected":"Disconnected");stateLabel.setTextColor(connected?0xff9bcdb4:MUTED);stateLabel.setContentDescription("SSH "+stateLabel.getText());connectButton.setText(connected?"Disconnect":"Connect");host.setEnabled(!busy&&!connected);login.setVisibility(connected?View.GONE:View.VISIBLE);serviceSwitch.setEnabled(!busy&&connected&&model!=null&&model.global!=null);serviceSwitch.setAlpha(serviceSwitch.isEnabled()?1f:.45f);
        if(wasConnected&&!connected){toolsPanel.render(Collections.emptyList());status.setText("Router disconnected. Connect again to continue.");serviceSwitch.setChecked(false);}wasConnected=connected;
    }
    private void render(Snapshot snapshot){
        toolsPanel.render(snapshot.model.wifi);
        actions.removeIf(v->v!=refreshButton && v!=connectButton && v!=host && v!=user && v!=password);model=snapshot.model;serviceSwitch.setChecked(model.enabled);nodes.removeAllViews();tunnels.removeAllViews();
        for(RouterModel.Node node:model.nodes){
            View card=item("server",node.name,node.active?"Currently in use":node.location,node.active?"Active":"Inactive",node.active,node.active?"✓  Active":"Set Active",()->{if(node.active)return;operate(()->{if(model.global==null)throw new Exception("Passwall 2 global configuration is missing.");router.command("uci set "+RouterModel.quote(model.global+".node="+node.id)+" && uci commit passwall2 && /etc/init.d/passwall2 restart");return load();});},true,node.id);nodes.addView(card,itemParams());
        }
        for(RouterModel.Tunnel tunnel:snapshot.tunnels){
            View card=item(tunnel.id.toLowerCase(Locale.ROOT).contains("gaming")?"game":"home",tunnel.id,"1".equals(RouterModel.parse(model.raw).get("network."+tunnel.id+".disabled"))?"Disabled · ready to connect":"",tunnel.up?"Connected":"Disconnected",tunnel.up,tunnel.up?"Disconnect":"Connect",()->controlWireGuard(tunnel.id,tunnel.up),false);tunnels.addView(card,itemParams());
        }
        if(model.nodes.isEmpty())empty(nodes,"No Passwall 2 nodes configured.");renderSubscriptions();if(snapshot.tunnels.isEmpty())empty(tunnels,"No WireGuard interfaces configured.");
    }
    private LinearLayout.LayoutParams itemParams(){LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,-2);p.bottomMargin=dp(9);return p;}
    private View item(String glyph,String name,String subtitle,String state,boolean active,String action,Runnable run,boolean menu){return item(glyph,name,subtitle,state,active,action,run,menu,"");}
    private View item(String glyph,String name,String subtitle,String state,boolean active,String action,Runnable run,boolean menu,String nodeId){
        LinearLayout card=row();card.setPadding(dp(11),dp(12),dp(11),dp(12));card.setBackground(shape(active?0xff152c24:0xff131e22,active?0xff457a56:0xff2a3936,12));
        FrameLayout iconBox=new FrameLayout(this);iconBox.setBackground(shape(active?0xff203b30:0xff1b282b,0xff2b3b3a,10));Icon icon=new Icon(glyph,active?GREEN:MUTED);iconBox.addView(icon,new FrameLayout.LayoutParams(dp(18),dp(19),Gravity.CENTER));card.addView(iconBox,new LinearLayout.LayoutParams(dp(32),dp(36)));
        LinearLayout copy=column();LinearLayout.LayoutParams cp=new LinearLayout.LayoutParams(0,-2,1);cp.leftMargin=dp(10);cp.rightMargin=dp(8);card.addView(copy,cp);TextView title=text(name,14,TEXT);title.setTypeface(null,Typeface.BOLD);title.setSingleLine(true);title.setEllipsize(TextUtils.TruncateAt.END);title.setContentDescription(name);copy.addView(title);space(copy,6);
        int color=active?0xff85e2b0:state.equals("Disconnected")?RED:0xff96a7ac;TextView pill=text("●  "+state,10,color);pill.setPadding(dp(6),dp(3),dp(6),dp(3));pill.setBackground(shape(active?0xff203f2f:0xff1d292c,0,6));copy.addView(pill,new LinearLayout.LayoutParams(-2,-2));
        if(!subtitle.isEmpty()){space(copy,5);TextView sub=text(subtitle,10,MUTED);sub.setSingleLine(true);sub.setEllipsize(TextUtils.TruncateAt.END);copy.addView(sub);}
        Button command=button(action,active);command.setTextSize(11);command.setPadding(dp(10),0,dp(10),0);command.setOnClickListener(v->run.run());command.setContentDescription(action+" "+name);card.addView(command,new LinearLayout.LayoutParams(-2,dp(44)));actions.add(command);
        if(menu){Button dots=button("⋮",false);dots.setTextSize(20);dots.setPadding(0,0,0,0);dots.setBackground(ripple(Color.TRANSPARENT,0,6));dots.setContentDescription("More options for "+name);card.addView(dots,new LinearLayout.LayoutParams(dp(30),dp(44)));dots.setOnClickListener(v->{PopupMenu popup=new PopupMenu(this,dots);popup.getMenu().add("Open in LuCI");popup.getMenu().add("Delete config");popup.setOnMenuItemClickListener(item->{if(item.getTitle().equals("Delete config")){new AlertDialog.Builder(this).setTitle("Delete configuration?").setMessage("Delete “"+name+"”?\n\nSubscription nodes may return after an update. Active or referenced nodes must be unlinked first.").setNegativeButton("Cancel",null).setPositiveButton("Delete",(d,w)->importNodes("delete","","",nodeId)).show();return true;}Uri uri=new Uri.Builder().scheme("http").encodedAuthority(connectedHost.contains(":")?"["+connectedHost+"]":connectedHost).path("/cgi-bin/luci/admin/services/passwall2").build();openUrl(uri.toString());return true;});popup.show();});actions.add(dots);}
        return card;
    }
    private void controlWireGuard(String id,boolean disconnect){
        if(busy||!router.connected())return;
        setBusy(true);status.setText(disconnect?"Disconnecting WireGuard and Iran Direct routing…":"Selecting WireGuard and enabling Iran Direct routing…");
        worker.execute(()->{
            String result="";Exception failure=null;Snapshot snapshot=null;
            try{
                if(!id.matches("[A-Za-z0-9_]+"))throw new Exception("Invalid WireGuard interface.");
                String script;try(java.io.InputStream in=getAssets().open("wireguard-control.sh")){java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream();byte[] buffer=new byte[4096];int n;while((n=in.read(buffer))!=-1)out.write(buffer,0,n);script=out.toString("UTF-8");}
                result=router.command("sh -c "+RouterModel.quote(script)+" raywrt-wg-control "+RouterModel.quote(disconnect?"disconnect":"connect")+" "+RouterModel.quote(id),180);
            }catch(Exception ex){failure=ex;}
            if(router.connected())try{snapshot=load();}catch(Exception ex){if(failure==null)failure=ex;}
            final Snapshot loaded=snapshot;final String message=result;final Exception error=failure;
            main.post(()->{if(isFinishing()||isDestroyed())return;if(loaded!=null)render(loaded);setBusy(false);syncConnection();status.setText(error==null?message.trim():"Error: "+error.getMessage());});
        });
    }
    private void selectTools(){passPanel.setVisibility(View.GONE);wirePanel.setVisibility(View.GONE);toolsPanel.setVisibility(View.VISIBLE);passTab.setBackground(ripple(Color.TRANSPARENT,0,10));wireTab.setBackground(ripple(Color.TRANSPARENT,0,10));routerTab.setBackground(ripple(0xff214333,0xff416b50,10));scroll.smoothScrollTo(0,0);}
    private void runTool(String command,String message,Runnable after){
        if(busy||!router.connected())return;setBusy(true);status.setText("Updating router…");worker.execute(()->{
            try{router.command(command);}catch(Exception e){postError(e);return;}
            Snapshot loaded=null;boolean reboot=command.equals(RouterTools.REBOOT);
            if(reboot)router.close();else try{Thread.sleep(3500);loaded=load();}catch(Exception ignored){}
            final Snapshot snapshot=loaded;
            main.post(()->{if(isDestroyed())return;if(snapshot!=null)render(snapshot);else toolsPanel.render(Collections.emptyList());if(after!=null)after.run();setBusy(false);syncConnection();status.setText(message+(!reboot&&snapshot==null?" Live state unavailable; reconnect and Refresh.":""));});
        });
    }
    private void runPing(){
        if(busy)return;setBusy(true);toolsPanel.pingStarted();status.setText("Running EU gaming diagnostic…");worker.execute(()->{try{
            String script;try(java.io.InputStream in=getAssets().open("raywrt-diagnostics")){java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream();byte[] buffer=new byte[4096];int n;while((n=in.read(buffer))!=-1)out.write(buffer,0,n);script=out.toString("UTF-8");}
            RouterTools.PingResult report=RouterTools.ping(router.command("sh -c "+RouterModel.quote(script)+" raywrt run"));main.post(()->{if(isDestroyed())return;toolsPanel.renderPing(report);status.setText("Diagnostic complete · 15 targets tested");setBusy(false);});
        }catch(Exception e){main.post(()->toolsPanel.pingFailed());postError(e);}});
    }
    private void showAddNode(){
        if(busy||!router.connected())return;
        LinearLayout content=column();content.setPadding(dp(24),dp(12),dp(24),dp(8));
        Spinner kind=new Spinner(this);kind.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"Node link","Subscription URL"}));content.addView(kind);space(content,14);
        content.addView(text("Link",12,MUTED));space(content,7);EditText link=field("",false);link.setSaveEnabled(false);link.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO);content.addView(link);space(content,14);
        content.addView(text("Name (optional)",12,MUTED));space(content,7);EditText name=field("",false);name.setSaveEnabled(false);content.addView(name);space(content,14);
        content.addView(text("Uses your router’s Passwall 2 importer. Subscriptions are saved for manual updates.",12,MUTED));space(content,10);TextView error=text("",12,RED);content.addView(error);
        Dialog dialog=new Dialog(this);dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        LinearLayout shell=column();shell.setPadding(dp(20),dp(22),dp(20),dp(16));shell.setBackground(shape(PANEL,0xff354542,18));
        TextView title=text("Add to Passwall 2",21,TEXT);title.setTypeface(null,Typeface.BOLD);shell.addView(title);space(shell,18);
        ScrollView form=new ScrollView(this);form.setVerticalScrollBarEnabled(false);content.setPadding(0,0,0,dp(12));form.addView(content);shell.addView(form,new LinearLayout.LayoutParams(-1,0,1));
        space(shell,14);LinearLayout buttons=row();Button cancel=button("Cancel",false),add=button("＋ Add",true);cancel.setTextSize(14);add.setTextSize(14);cancel.setContentDescription("Cancel adding node");add.setContentDescription("Import node or subscription");
        LinearLayout.LayoutParams left=new LinearLayout.LayoutParams(0,dp(48),1);left.rightMargin=dp(6);buttons.addView(cancel,left);LinearLayout.LayoutParams right=new LinearLayout.LayoutParams(0,dp(48),1);right.leftMargin=dp(6);buttons.addView(add,right);shell.addView(buttons);
        cancel.setOnClickListener(v->dialog.dismiss());add.setOnClickListener(v->{String mode=kind.getSelectedItemPosition()==0?"node":"subscription",value=link.getText().toString().trim(),label=name.getText().toString().trim();try{NodeImport.validate(mode,value,label,"");dialog.dismiss();importNodes(mode,value,label,"");}catch(Exception e){error.setText(e.getMessage());form.post(()->form.smoothScrollTo(0,content.getHeight()));}});
        dialog.setContentView(shell);Window window=dialog.getWindow();window.setBackgroundDrawableResource(android.R.color.transparent);window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);dialog.show();
        android.util.DisplayMetrics metrics=getResources().getDisplayMetrics();window.setLayout(Math.min(dp(520),metrics.widthPixels-dp(32)),Math.min(dp(460),metrics.heightPixels-dp(80)));window.getDecorView().getViewTreeObserver().addOnGlobalLayoutListener(()->{Rect visible=new Rect();window.getDecorView().getWindowVisibleDisplayFrame(visible);int height=Math.min(dp(460),Math.max(dp(180),visible.height()-dp(32)));if(window.getAttributes().height!=height)window.setLayout(Math.min(dp(520),metrics.widthPixels-dp(32)),height);});
    }
    private void showWireGuardImport(){
        if(busy||!router.connected())return;
        Dialog dialog=new Dialog(this);dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        LinearLayout shell=column();shell.setPadding(dp(20),dp(22),dp(20),dp(16));shell.setBackground(shape(PANEL,0xff354542,18));
        TextView title=text("Import WireGuard",21,TEXT);title.setTypeface(null,Typeface.BOLD);shell.addView(title);space(shell,16);
        ScrollView form=new ScrollView(this);form.setVerticalScrollBarEnabled(false);shell.addView(form,new LinearLayout.LayoutParams(-1,0,1));LinearLayout content=column();form.addView(content);
        content.addView(text("Interface name",12,MUTED));space(content,7);wireNameField=field("wg_import",false);content.addView(wireNameField);space(content,14);
        content.addView(text("WireGuard .conf",12,MUTED));space(content,7);wireConfigField=field("",false);wireConfigField.setSingleLine(false);wireConfigField.setMinLines(5);wireConfigField.setGravity(Gravity.TOP|Gravity.START);wireConfigField.setSaveEnabled(false);wireConfigField.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO);content.addView(wireConfigField,new LinearLayout.LayoutParams(-1,dp(150)));space(content,10);
        Button choose=button("Choose .conf file",false);choose.setOnClickListener(v->{Intent pick=new Intent(Intent.ACTION_OPEN_DOCUMENT);pick.addCategory(Intent.CATEGORY_OPENABLE);pick.setType("*/*");startActivityForResult(pick,2401);});content.addView(choose,new LinearLayout.LayoutParams(-1,dp(44)));space(content,13);
        content.addView(text("Saves the interface in the WAN firewall zone. Press Connect later to activate it.",12,MUTED));space(content,8);TextView error=text("",12,RED);content.addView(error);
        space(shell,12);LinearLayout buttons=row();Button cancel=button("Cancel",false),add=button("Import",true);LinearLayout.LayoutParams left=new LinearLayout.LayoutParams(0,dp(48),1);left.rightMargin=dp(6);buttons.addView(cancel,left);LinearLayout.LayoutParams right=new LinearLayout.LayoutParams(0,dp(48),1);right.leftMargin=dp(6);buttons.addView(add,right);shell.addView(buttons);
        cancel.setOnClickListener(v->dialog.dismiss());add.setOnClickListener(v->{String name=wireNameField.getText().toString().trim(),config=wireConfigField.getText().toString();try{WireGuardImport.command(name,config);dialog.dismiss();wireNameField=null;wireConfigField=null;importWireGuard(name,config);}catch(Exception ex){error.setText(ex.getMessage());form.post(()->form.smoothScrollTo(0,content.getHeight()));}});
        dialog.setOnDismissListener(v->{wireNameField=null;wireConfigField=null;});dialog.setContentView(shell);Window window=dialog.getWindow();window.setBackgroundDrawableResource(android.R.color.transparent);window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);dialog.show();android.util.DisplayMetrics metrics=getResources().getDisplayMetrics();window.setLayout(Math.min(dp(520),metrics.widthPixels-dp(32)),Math.min(dp(460),metrics.heightPixels-dp(80)));window.getDecorView().getViewTreeObserver().addOnGlobalLayoutListener(()->{Rect visible=new Rect();window.getDecorView().getWindowVisibleDisplayFrame(visible);int height=Math.min(dp(460),Math.max(dp(180),visible.height()-dp(32)));if(window.getAttributes().height!=height)window.setLayout(Math.min(dp(520),metrics.widthPixels-dp(32)),height);});
    }
    @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(request!=2401||result!=RESULT_OK||data==null||wireConfigField==null)return;try(java.io.InputStream in=getContentResolver().openInputStream(data.getData())){if(in==null)throw new Exception("Cannot read file.");java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream();byte[] bytes=new byte[4096];int n;while((n=in.read(bytes))!=-1){out.write(bytes,0,n);if(out.size()>65536)throw new Exception("File exceeds 64 KB.");}wireConfigField.setText(out.toString("UTF-8"));String segment=data.getData().getLastPathSegment();if(segment!=null&&wireNameField!=null){String base=segment.substring(segment.lastIndexOf('/')+1).replaceFirst("(?i)\\.conf$","").toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9_]","_");if(base.matches("[a-z][a-z0-9_]{0,14}"))wireNameField.setText(base);}}catch(Exception ex){status.setText("Could not read .conf: "+ex.getMessage());}}
    private void importWireGuard(String name,String config){if(busy||!router.connected())return;setBusy(true);status.setText("Importing WireGuard configuration…");worker.execute(()->{try{String result=router.command(WireGuardImport.command(name,config),60);Snapshot snapshot=load();main.post(()->{if(isDestroyed())return;render(snapshot);setBusy(false);status.setText(result.trim());});}catch(Exception ex){postError(ex);}});}
    private void importNodes(String mode,String link,String name,String id){
        if(busy||!router.connected())return;setBusy(true);status.setText(mode.equals("update")?"Updating subscription…":"Importing nodes…");
        worker.execute(()->{try{
            String script;try(java.io.InputStream in=getAssets().open("node-import.lua")){java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream();byte[] b=new byte[4096];int n;while((n=in.read(b))!=-1)out.write(b,0,n);script=out.toString("UTF-8");}
            String result=router.command(NodeImport.command(script,mode,link,name,id),240);Snapshot snapshot=load();main.post(()->{if(isDestroyed())return;render(snapshot);setBusy(false);syncConnection();status.setText(result.trim());});
        }catch(Exception e){postError(e);}});
    }
    private void renderSubscriptions(){
        Map<String,String> data=RouterModel.parse(model.raw);boolean heading=false;
        for(Map.Entry<String,String> e:data.entrySet())if(e.getKey().startsWith("passwall2.")&&e.getValue().equals("subscribe_list")){
            if(!heading){space(nodes,15);nodes.addView(text("SUBSCRIPTIONS",10,MUTED));space(nodes,12);heading=true;}
            String id=e.getKey().substring(10),label=data.getOrDefault(e.getKey()+".remark",id);
            nodes.addView(item("globe",label,"Manual updates","Saved",false,"Update",()->importNodes("update","","",id),false),itemParams());
        }
    }
    private void openUrl(String link){try{startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse(link)));}catch(ActivityNotFoundException ex){status.setText("No browser available to open this link.");}}
    @Override protected void onStart(){super.onStart();if(pulse!=null)pulse.start();main.removeCallbacks(watch);main.post(watch);}
    @Override protected void onStop(){super.onStop();main.removeCallbacks(watch);if(pulse!=null)pulse.stop();}
    @Override public void onConfigurationChanged(Configuration c){super.onConfigurationChanged(c);root.requestApplyInsets();}
    @Override protected void onDestroy(){main.removeCallbacksAndMessages(null);worker.shutdownNow();router.close();if(pulse!=null)pulse.stop();super.onDestroy();}

    private final class PulseDot extends View {
        private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);private boolean connected;private float halo=.05f;private ValueAnimator animator;
        PulseDot(){super(MainActivity.this);setContentDescription("Router disconnected");}
        void setConnected(boolean value){connected=value;setContentDescription(value?"Router connected":"Router disconnected");invalidate();}
        void start(){stop();if(!ValueAnimator.areAnimatorsEnabled())return;animator=ValueAnimator.ofFloat(0,1);animator.setDuration(2800);animator.setRepeatCount(ValueAnimator.INFINITE);animator.setInterpolator(new android.view.animation.LinearInterpolator());animator.addUpdateListener(a->{float t=(float)a.getAnimatedValue()*2800;float first=(float)Math.exp(-Math.pow((t-180)/110,2));float second=(float)Math.exp(-Math.pow((t-580)/120,2));halo=.035f+.12f*first+.075f*second;invalidate();});animator.start();}
        void stop(){if(animator!=null){animator.cancel();animator=null;}halo=.05f;invalidate();}
        @Override protected void onDraw(Canvas canvas){float x=getWidth()/2f,y=getHeight()/2f;paint.setColor(connected?GREEN:RED);paint.setAlpha((int)(255*halo));canvas.drawCircle(x,y,dp(8),paint);paint.setAlpha(204);canvas.drawCircle(x,y,dp(3),paint);}
    }
    private final class Icon extends View {
        private final String type;private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
        Icon(String type,int color){super(MainActivity.this);this.type=type;paint.setColor(color);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(1.5f);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);}
        @Override protected void onDraw(Canvas c){c.save();c.scale(getWidth()/24f,getHeight()/24f);Path p=new Path();switch(type){
            case "globe":c.drawCircle(12,12,10,paint);c.drawLine(2,12,22,12,paint);c.drawOval(7,2,17,22,paint);break;
            case "router":c.drawLine(4,13,4,4,paint);c.drawLine(20,13,20,4,paint);c.drawRoundRect(1,13,23,22,2,2,paint);c.drawLine(5,18,6,18,paint);c.drawLine(10,18,11,18,paint);c.drawLine(18,18,20,18,paint);break;
            case "server":c.drawRoundRect(2,3,22,10,1,1,paint);c.drawRoundRect(2,14,22,21,1,1,paint);c.drawLine(6,6.5f,8,6.5f,paint);c.drawLine(6,17.5f,8,17.5f,paint);c.drawPoint(18,6.5f,paint);c.drawPoint(18,17.5f,paint);break;
            case "home":p.moveTo(2,11);p.lineTo(12,2);p.lineTo(22,11);p.moveTo(5,9);p.lineTo(5,22);p.lineTo(10,22);p.lineTo(10,15);p.lineTo(14,15);p.lineTo(14,22);p.lineTo(19,22);p.lineTo(19,9);c.drawPath(p,paint);break;
            case "game":p.moveTo(7,6);p.lineTo(17,6);p.quadTo(20,6,21,10);p.lineTo(23,18);p.quadTo(23,22,20,20);p.lineTo(16,16);p.lineTo(8,16);p.lineTo(4,20);p.quadTo(1,22,1,18);p.lineTo(3,10);p.quadTo(4,6,7,6);c.drawPath(p,paint);c.drawLine(5,11,11,11,paint);c.drawLine(8,8,8,14,paint);c.drawPoint(16,10,paint);c.drawPoint(19,13,paint);break;
            default:p.moveTo(12,2);p.lineTo(21,6);p.lineTo(21,12);p.cubicTo(21,17,17,21,12,23);p.cubicTo(7,21,3,17,3,12);p.lineTo(3,6);p.close();c.drawPath(p,paint);break;
        }c.restore();}
    }
}






















