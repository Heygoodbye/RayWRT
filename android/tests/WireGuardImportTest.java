package io.github.heygoodbye.raywrt;

public final class WireGuardImportTest {
 static final String VALID="[Interface]\nPrivateKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\nAddress = 10.9.0.2/24, fd00::2/64\nDNS = 1.1.1.1\nMTU = 1420\n[Peer]\nPublicKey = BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=\nAllowedIPs = 0.0.0.0/0, ::/0\nEndpoint = vpn.example.com:51820\nPersistentKeepalive = 25\n";
 static void rejected(String config) throws Exception {try{WireGuardImport.command("wg_new",config);throw new AssertionError("Invalid configuration accepted");}catch(AssertionError e){throw e;}catch(Exception expected){}}
 public static void main(String[] args)throws Exception{
  if(args.length>0&&args[0].equals("--command")){System.out.print(WireGuardImport.command("wg_new",VALID));return;}
  String command=WireGuardImport.command("wg_new",VALID);
  if(command.contains("lua ")||command.contains("base64 ")||!command.contains("uci add_list")||!command.contains("uci commit firewall"))throw new AssertionError("Unexpected router dependency or missing UCI write");
  rejected(VALID.replace("PublicKey", "PostUp"));
  rejected(VALID.replace("BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=", "bad"));
  rejected(VALID.replace("10.9.0.2/24", "not-an-address"));
  rejected(VALID.replace("vpn.example.com:51820", "vpn.example.com:99999"));
  System.out.println("PASS: WireGuard client parsing and UCI command validation");
 }
}
