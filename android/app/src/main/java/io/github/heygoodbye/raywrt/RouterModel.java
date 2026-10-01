package io.github.heygoodbye.raywrt;

import java.util.*;
import java.util.regex.Pattern;

public final class RouterModel {
    public static final class Node {
        public final String id, name, location;
        public final boolean active;
        Node(String id,String name,String location,boolean active){this.id=id;this.name=name;this.location=location;this.active=active;}
    }
    public static final class Tunnel {
        public final String id; public final boolean up;
        public Tunnel(String id,boolean up){this.id=id;this.up=up;}
    }
    public final List<RouterTools.Wifi> wifi;
    public final String raw;
    public final String global;
    public final boolean enabled;
    public final List<Node> nodes;
    public final List<String> tunnelIds;
    public RouterModel(String raw) {
        this.raw=raw;Map<String,String> data=parse(raw);wifi=RouterTools.wireless(raw);
        String found=null;
        for(Map.Entry<String,String> pair:data.entrySet()) if(pair.getKey().startsWith("passwall2.") && pair.getValue().equals("global")){found=pair.getKey();break;}
        global=found;enabled=found!=null && "1".equals(data.get(found+".enabled"));
        String active=found==null?"":data.get(found+".node");
        nodes=new ArrayList<>();tunnelIds=new ArrayList<>();
        for(Map.Entry<String,String> pair:data.entrySet()) {
            String key=pair.getKey();
            if(key.startsWith("passwall2.") && pair.getValue().equals("nodes")) {
                String id=key.substring(10),name=data.get(key+".remarks"),address=data.get(key+".address");
                nodes.add(new Node(id,name==null||name.isEmpty()?id:name,address==null?"Configured node":address,id.equals(active)));
            }
            if(key.startsWith("network.") && key.endsWith(".proto") && "wireguard".equals(pair.getValue())){
                String id=key.substring(8,key.length()-6);
                if(Pattern.matches("[A-Za-z0-9_]+",id))tunnelIds.add(id);
            }
        }
    }
    public static Map<String,String> parse(String raw){
        Map<String,String> result=new LinkedHashMap<>();
        for(String line:raw.split("\\r?\\n")){int i=line.indexOf('=');if(i>0)result.put(line.substring(0,i),unquote(line.substring(i+1).trim()));}
        return result;
    }
    static String unquote(String value){
        StringBuilder out=new StringBuilder();boolean quoted=false;
        for(int i=0;i<value.length();i++){char c=value.charAt(i);if(c=='\'')quoted=!quoted;else if(c=='\\' && !quoted && i+1<value.length())out.append(value.charAt(++i));else out.append(c);}
        return out.toString();
    }
    public static String quote(String value){return "'"+value.replace("'","'\\''")+"'";}
}
