package io.github.heygoodbye.raywrt;

import com.jcraft.jsch.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;

public final class RouterClient implements AutoCloseable {
    public interface Trust {
        String stored(String host);
        boolean confirm(String host,String fingerprint) throws Exception;
        void save(String host,String fingerprint);
    }
    private volatile Session session;
    public boolean connected(){Session current=session;return current!=null && current.isConnected();}
    public void connect(String host,String user,String password,Trust trust) throws Exception {
        close();
        JSch jsch=new JSch();
        final String[] pending=new String[1];
        jsch.setHostKeyRepository(new HostKeyRepository(){
            public int check(String hostname,byte[] key){
                try{
                    String fingerprint="SHA256:"+Base64.getEncoder().withoutPadding().encodeToString(MessageDigest.getInstance("SHA-256").digest(key));
                    String known=trust.stored(host);pending[0]=fingerprint;
                    if(known!=null && known.equals(fingerprint))return OK;
                    return trust.confirm(host,fingerprint)?OK:CHANGED;
                }catch(Exception ex){return CHANGED;}
            }
            public void add(HostKey key,UserInfo userInfo){}
            public void remove(String host,String type){}
            public void remove(String host,String type,byte[] key){}
            public String getKnownHostsRepositoryID(){return "RayWRT pinned router identities";}
            public HostKey[] getHostKey(){return new HostKey[0];}
            public HostKey[] getHostKey(String host,String type){return new HostKey[0];}
        });
        Session next=jsch.getSession(user,host,22);
        next.setConfig("StrictHostKeyChecking","yes");
        next.setConfig("PreferredAuthentications","password,keyboard-interactive");
        next.setPassword(password);
        next.setUserInfo(new UserInfo(){
            public String getPassphrase(){return null;}public String getPassword(){return password;}
            public boolean promptPassword(String message){return true;}public boolean promptPassphrase(String message){return false;}
            public boolean promptYesNo(String message){return false;}public void showMessage(String message){}
        });
        next.setServerAliveInterval(15000);next.setServerAliveCountMax(2);next.setTimeout(20000);
        try{next.connect(12000);if(pending[0]!=null && !pending[0].equals(trust.stored(host)))trust.save(host,pending[0]);session=next;}
        catch(Exception ex){next.disconnect();throw ex;}
    }
    public String command(String text) throws Exception {return command(text,30);}
    public String command(String text,int timeoutSeconds) throws Exception {
        Session current=session;if(current==null || !current.isConnected())throw new IOException("Connect to your router first.");
        ChannelExec channel=(ChannelExec)current.openChannel("exec");
        ByteArrayOutputStream output=new ByteArrayOutputStream(),error=new ByteArrayOutputStream();
        channel.setCommand(text);channel.setInputStream(null);channel.setOutputStream(output);channel.setErrStream(error);
        long deadline=System.currentTimeMillis()+timeoutSeconds*1000L;
        try{
            channel.connect(10000);
            while(!channel.isClosed()){
                if(Thread.currentThread().isInterrupted())throw new IOException("Operation cancelled.");
                if(System.currentTimeMillis()>deadline)throw new IOException("Router command timed out. Refresh to check its result.");
                if(output.size()+error.size()>2*1024*1024)throw new IOException("Router response exceeds the 2 MB limit.");
                Thread.sleep(40);
            }
            if(channel.getExitStatus()!=0){String message=error.toString("UTF-8").trim();throw new IOException(message.isEmpty()?"Router command failed ("+channel.getExitStatus()+").":message);}
            return output.toString("UTF-8");
        }finally{channel.disconnect();}
    }
    @Override public void close(){Session current=session;session=null;if(current!=null)current.disconnect();}
}

