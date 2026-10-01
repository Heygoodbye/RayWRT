import io.github.heygoodbye.raywrt.NodeImport;
public class NodeImportTest {
 public static void main(String[] a)throws Exception{
  NodeImport.validate("node","vless://id@eu.example:443#EU","","");
  NodeImport.validate("subscription","https://example.com/sub?token=abc","EU","");
  NodeImport.validate("update","","","@subscribe_list[0]");
  NodeImport.validate("update","","","cfg012abc");
  NodeImport.validate("delete","","","@nodes[2]");
  for(String s:new String[]{"", "garbage", "vless://x\nrm", "file:///etc/passwd"}){try{NodeImport.validate("node",s,"","");throw new AssertionError(s);}catch(Exception expected){}}
  try{NodeImport.validate("update","","","cfg;reboot");throw new AssertionError();}catch(Exception expected){}
  String cmd=NodeImport.command("print('test')","node","vless://a@host:443#x'$(touch_bad)","Alice's","");
  if(!cmd.contains("'\\''")||!cmd.contains("umask 077")||!cmd.contains("raywrt-node-import"))throw new AssertionError("quoting/permissions");
  System.out.println("PASS: node/subscription validation and command quoting");
 }
}
