//
//  pikon: a console management system
//

#include <pikon.h>

constant version="0.1.0";

object cmd;
object in, in2;
object tc;
object out;
object conn; // connection to pikon server

mapping oldattrs=0;

string user;
string pass;
string host;
int port;

int in_connect_mode=0;
int authenticated=0;

mixed history;
mapping prefs=([]);


int main(int argc, array argv)
{
  load_preferences();
  in=Stdio.stdin;
  out=Stdio.stdout;
  cmd=Stdio.Readline(in, 0, out, 0);
  cmd->message("Welcome to Pikon.");
  
  // do we want to connect automatically on startup?
  if(prefs->autoconnect)
  {
     if(prefs->autoconnect_host && prefs->autoconnect_port)    
       do_open(prefs->autoconnect_host + " " + prefs->autoconnect_port);
     else do_open();
  }

  set_prompt();
  cmd->enable_history(512);
  call_out(run_prompt,0);
  return -1;

}

void load_preferences()
{
   string f=Stdio.read_file("pikon.conf");
   mapping p=.Config.read(f);
   prefs=p->client||([]);
}

void run_prompt()
{
  string data;
  if(cmd) data=cmd->read();
  if(data) newline(data);
  if(cmd)
    run_prompt();
}

void newline(mixed data)
{
 {
   array c=((data/" ")-({""}));
   if(sizeof(c)!=0) switch(c[0])
   {
     case "login":
       if(sizeof(c)==1)
       {
         pause_history();
         do_login();
         resume_history();
       }
       else
       {
         pause_history();
         do_login(c[1..]*" ");
         resume_history();
       }
       break;
     case "monitor":
       if(sizeof(c)==1)
       {
         pause_history();
         do_monitor();
         resume_history();
       }
       else
       {
         pause_history();
         do_monitor(c[1..]*" ");
         resume_history();
       }
       break;
     case "open":
       if(sizeof(c)==1)
       {
         pause_history();
         do_open();
         resume_history();
       }
       else
       {
         pause_history();
         do_open(c[1..]*" ");
         resume_history();
       }
       break;
     case "connect":
       if(sizeof(c)==1)
       {
         pause_history();
         do_connect();
         resume_history();
       }
       else
       {
         pause_history();
         do_connect(c[1..]*" ");
         resume_history();
       }
       break;
     case "quit":
       do_quit();
       break;
     case "help":
       do_help();
       break;

     default:
       if(c[0]) cmd->write("Unrecognized command.\n");
       cmd->redisplay();
       break;       
   }   
   else
      cmd->redisplay();
 }
 return;
}

void do_open(void|string arg)
{
  if(connected())
    cmd->message("Already connected to " + host + ".");
  else
  {
    int pt;
    string hst;
    if(arg)
    {
      if(sscanf(arg, "%s %d", hst, pt)!=2)
      {
        cmd->message("Usage: open [host port]");
        return;
      }
      else
      {
         host=hst;
         port=pt;
      }
    }
    else  // let's gather host and port information.
    {
      cmd->set_prompt("");
      string hst;
      do 
      {
        hst=cmd->read("host: ");
      }
      while(!hst);
      host=hst;

      cmd->set_prompt("");
      int pt;
      string p;
      do 
      {
        p=cmd->read("port: ");
      }
      while(!sscanf(p, "%d", pt));
      port=pt;
    }
    
    if(catch(conn=Pikon.remote_client(host, port, this_object())))
    {
      cmd->message("Unable to connect to " + host + " port " + port + ".");
      set_prompt();
    }
    else
    {
      cmd->message("Connected to " + host + " port " + port + ".\n"
                   "Server: " + conn->server_version());
      set_prompt();
    }
  }  
}

void do_monitor(void|string arg)
{
  if(!connected())
    cmd->message("You must be connected to a Pikon server first.");
  else
  {
    string hst,conname;
    if(arg)
    {
      if(sscanf(arg, "%s", hst)!=1)
      {
        cmd->message("Usage: monitor [console]");
        return;
      }
      else
      {
         conname=hst;
      }
    }
    else  // let's gather console information.
    {
      cmd->set_prompt("");
      string hst;
      do 
      {
        hst=cmd->read("console: ");
      }
      while(!hst);
      conname=hst;
    }
    string cn;
    if(cn=conn->monitor(conname))
    {
      cmd->message(conn->last_response + "\n"
                   "Press enter/return key to exit MONITOR mode.\n");
      conn->set_monitor_callback(monitor_mode_read);
      cmd->destroy();
      cmd=0;    
      in2=Stdio.File("stdin");
      in2->set_nonblocking();
      in2->set_read_callback(monitor_mode_read_from_client);
      in2->set_nonblocking_keep_callbacks();
    }
    else
    {
      cmd->message("Unable to connect to requested console. Server said: " 
	+ conn->last_response);
    }
  }  
}

void do_connect(void|string arg)
{
  if(!connected())
    cmd->message("You must be connected to a Pikon server first.");
  else
  {
    string hst,conname;
    if(arg)
    {
      if(sscanf(arg, "%s", hst)!=1)
      {
        cmd->message("Usage: connect [console]");
        return;
      }
      else
      {
         conname=hst;
      }
    }
    else  // let's gather console information.
    {
      cmd->set_prompt("");
      string hst;
      do 
      {
        hst=cmd->read("console: ");
      }
      while(!hst);
      conname=hst;
    }
    string cn;
    if(cn=conn->connectrw(conname))
    {
      cmd->message(conn->last_response + "\n"
                   "Press ^-\\ to view options.\n");
      conn->set_monitor_callback(connect_mode_read);
      in_connect_mode=1;
      cmd->destroy();
      cmd=0;    
      in2=Stdio.File("stdin");
      tc=Stdio.Terminfo.getTerm();    
      catch{ oldattrs=in2->tcgetattr(); };
      if(catch(in2->tcsetattr((["VMIN":1, "VTIME":0, "ISIG":0, 
        "ICANON":0, "ECHO":0]))))
        write("ERROR SETTING TERM ATTRIBUTES!\n");
      in2->set_nonblocking();
      in2->set_read_callback(connect_mode_read_from_client);
    }
    else
    {
      cmd->message("Unable to connect to requested console. Server said: " 
	+ conn->last_response);
    }
  }  
}

void do_login(void|string arg)
{
  if(!connected())
  {
    cmd->message("You are not connected. Use 'connect' to establish a server session before logging in.");
    return;
  }
  if(authenticated)
  {
    cmd->message("Already logged in as " + user + ".");
    return;
  }
  cmd->set_prompt("");
  user=cmd->read("username: ");
  cmd->set_echo(0);
  pass=cmd->read("password: ");
  cmd->set_echo(1); 
  set_prompt();

  int res=conn->login(user, pass);
  if(res)
  {
    authenticated=1;
    cmd->message("login successful.");
  }
  else
  {
    cmd->message("login failed.");
  }
}

void set_prompt()
{
  cmd->set_prompt("Pikon> ");
}

void do_logout()
{
  if(!connected())
  {
    cmd->message("Not connected.");
  }
  else
  {
    conn->logout();
    user="";
    pass="";
    authenticated=0;
    cmd->message("Logged out.");
  }
}

void do_disconnect()
{
  if(!connected())
  {
    cmd->message("Not connected.");
  }
  else
  {
    if(authenticated)
      conn->logout();
    user="";
    pass="";
    authenticated=0;
    conn->disconnect();
    host="";
    port=0;
    cmd->message("Disconnected from " + host + " port " + port + ".");
  }
}

void do_help()
{
  cmd->write(CLIENT_HELP_MESSAGE);

}

void do_quit()
{
  cmd->set_prompt("");
  cmd->destroy();
  if(connected())
  {
    conn->logout();
  }
  exit(1);
}

int connected()
{
  if(conn && conn->is_connected())
    return 1;
  else return 0;
}

void pause_history()
{
   history=cmd->get_history();
   cmd->enable_history(0);
}

void resume_history()
{
  if(cmd && history && !intp(history))
    cmd->enable_history(history);
}

void monitor_mode_read(mixed data)
{
  if(data=="\000ENDMONITOR")
  {
     out->write("\n");
     end_monitor_mode();
  }  
  else
    out->write(data);
}
void connect_mode_read(mixed data)
{
  if(data[0..10]=="\000ENDCONNECT")
  {
     out->write("CONNECT session closed.\n");
     end_connect_mode();
  }  
  else
    out->write(data);
}

void end_connect_mode()
{
  catch{ in2->tcsetattr(oldattrs); };
  in2=0;
  in_connect_mode=0;
  cmd=Stdio.Readline(in, 0, out, 0);
  if(history)
    cmd->enable_history(history);
  else 
    cmd->enable_history(512);
  set_prompt();
  call_out(run_prompt, 0);

}

void end_monitor_mode()
{
  in2=0;

}

void monitor_mode_read_from_client(int id, mixed data)
{
  conn->monitor_send_data(data);
  cmd=Stdio.Readline(in, 0, out, 0);
  if(history)
    cmd->enable_history(history);
  else 
    cmd->enable_history(512);
  set_prompt();
  call_out(run_prompt, 0);
}

void connect_mode_read_from_client(int id, mixed data)
{
  if(data)
  {
    conn->connect_send_data(data);
  }
}

