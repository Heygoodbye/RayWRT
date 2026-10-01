import java.util.*;
import io.github.heygoodbye.raywrt.RouterModel;
public final class ModelTest {
 public static void main(String[] args) {
  String config="passwall2.@global[0]=global\npasswall2.@global[0].enabled='1'\npasswall2.@global[0].node='node1'\npasswall2.node1=nodes\npasswall2.node1.remarks='Alice'\\''s node'\npasswall2.node1.address='frankfurt.example'\nnetwork.wg_home=interface\nnetwork.wg_home.proto='wireguard'\nnetwork.lan.proto='static'\nnetwork.bad;id.proto='wireguard'\n";
  RouterModel m=new RouterModel(config);
  check(m.enabled,"enabled flag");check(m.global.equals("passwall2.@global[0]"),"anonymous global section");check(m.nodes.size()==1 && m.nodes.get(0).active,"active node selection");check(m.nodes.get(0).name.equals("Alice's node"),"escaped UCI apostrophe");check(m.tunnelIds.equals(Arrays.asList("wg_home")),"WireGuard filtering and interface validation");check(RouterModel.quote("a';touch /tmp/b").equals("'a'\\'';touch /tmp/b'"),"shell argument quoting");check(new RouterModel("").global==null,"missing configuration");
  System.out.println("PASS: 7 router model checks");
 }
 static void check(boolean okay,String label){if(!okay)throw new AssertionError(label);}
}
