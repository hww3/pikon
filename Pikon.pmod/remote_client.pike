object conn;
string write_buffer="";
string remote_server_version;
int in_remote_mode=0;
string current_mode="";
int in_connect_command_mode=0;
string last_response="";
function monitor_cb;
string escape_character="\d28";

#include <pikon.h>

void create(string host, int port, object this)
{
  conn=Stdio.File();

  if(!conn->connect(host, port))
  {
    werror("Unable to connect to " + host + " port " + port+ ".");
    error("Unable to connect to " + host + " port " + port+ ".");
  }
  else
  {
    // get welcome banner
    if(read_response()/100 !=2) 
	error("No Pikon Server at " + host + " port " + port + ".");  
    conn->set_nonblocking();
    conn->set_read_callback(read_remote_connection);
    conn->set_write_callback(write_remote_connection);
    conn->set_close_callback(close_remote_connection);
  }
}

void read_remote_connection(mixed id, string data)
{
   // is this a connect keepalive message?
   if(data[0..6]=="\000ALIVE?")
     return;
   if(in_remote_mode) // we're in monitor or console mode.
   {
     if(monitor_cb) monitor_cb(data);
   }

}

void write_remote_connection(mixed id)
{
  if(sizeof(write_buffer)!=0)
  {
    int written=conn->write(write_buffer);
    if(written) // remove written bytes from write_buffer.
    {
      if(written < sizeof(write_buffer))
        write_buffer=write_buffer[written..];
      else
        write_buffer="";
    }
  }
}

void close_remote_connection(mixed id)
{
  if(in_remote_mode)
  {
    monitor_cb("\n");
    monitor_cb("Connection to Pikon Server lost.\n");
    if(current_mode=="connect")
      monitor_cb("\000ENDCONNECT");
    else if(current_mode=="monitor")
      monitor_cb("Press enter/return key to continue.");
    in_remote_mode=0;
    current_mode="";
    monitor_cb=0;
  }
}

int is_connected()
{
  if(conn && (send_command("VERSION")/100)==2)
    return 1;
  else return 0;
}

string server_version()
{
  int res=send_command("VERSION");
  if(res/100 !=2) return "Server Version Unavailable";
  remote_server_version=last_response;
  return remote_server_version;
}

void send(string what)
{
  int r=conn->write(what);
  if(r<sizeof(what))
    write_buffer+=what[r..];
}

void logout()
{
  send_command("LOGOUT");
  return;
}

int login(string user, string pass)
{
  if(send_command("USER " + user)/100 !=2) return 0;
  if(send_command("PASS " + pass)/100 !=2) return 0;
  return 1;
}

int monitor(string con)
{
  if(send_command("MONITOR " + con)/100 !=2) return 0;
  in_remote_mode=1;
  current_mode="monitor";
//  mixed r=conn->read(1024,1);
//  if(r) read_remote_connection(1, r);
    conn->set_nonblocking();
    conn->set_read_callback(read_remote_connection);
    conn->set_write_callback(write_remote_connection);
    conn->set_close_callback(close_remote_connection);
  return 1;
}

int connectrw(string con)
{
  if(send_command("CONNECT " + con)/100 !=2) return 0;
  in_remote_mode=1;
  current_mode="connect";
  conn->set_nonblocking();
  conn->set_read_callback(read_remote_connection);
  conn->set_write_callback(write_remote_connection);
  conn->set_close_callback(close_remote_connection);
  return 1;
}

int set_monitor_callback(function f)
{
  monitor_cb=f;
  return 1;
}

int send_command(string cmd)
{
  if(!conn) return 405; // no connection.

  string res, desc;
  int code,r;
  conn->set_blocking();
  if(catch(r=conn->write(cmd + "\r\n"))) //has connection closed on us?
  {
    conn=0;
    last_response="Connection to Pikon server lost.";
    return 402;
  }
  if(r<sizeof(cmd)+2) werror("didn't write whole command...\n");
  return read_response();
}

int read_response()
{
  int code;
  string res, desc;

  conn->set_blocking();
  if(catch(res=conn->read(1024, 1)))
  {
    last_response="Connection to Pikon server lost.";
    return 402;
  }
  if(!res)
  {
    conn=0;
    last_response="Connection to Pikon server lost.";
    return 402;
  }
  conn->set_nonblocking();
    conn->set_read_callback(read_remote_connection);
    conn->set_write_callback(write_remote_connection);
    conn->set_close_callback(close_remote_connection);

  if(sscanf(res, "%d %s\r\n", code, desc)!=2)
  {
    conn=0;
    return 402; // lost connection or connection is invalid.
  }
  last_response=desc;
  return code;
}

void monitor_send_data(mixed data)
{
  data="\000ENDMONITOR";
  if(send_command(data))
  {    
    if(monitor_cb) 
    {
      monitor_cb(last_response+"\n");
      monitor_cb("\000ENDMONITOR");
      in_remote_mode=0;
      current_mode="";
      monitor_cb=0;
    }
  }
}

void connect_send_data(mixed data)
{
    if(data[0..0]==escape_character)
    {
      in_connect_command_mode=1;
      monitor_cb(CONNECT_MENU_OPTIONS);      
      monitor_cb(CONNECT_MENU_PROMPT);
    }
    else if(in_connect_command_mode && data[0..0]=="x")
    {
      in_connect_command_mode=0;
      monitor_cb(data + "\n");
    }
    else if(in_connect_command_mode && data[0..0]=="b")
    {
      in_connect_command_mode=0;
      monitor_cb(data + "\n");
      conn->write("\xff\xf3");
    }
    else if(in_connect_command_mode && data[0..0]=="q")
    {
      in_connect_command_mode=0;
      data="\000ENDCONNECT";
      if((send_command(data)/100)==2)
      {    
        if(monitor_cb) 
        {
          monitor_cb("\n");
          monitor_cb(last_response+"\n");
          monitor_cb("\000ENDCONNECT");
          current_mode="";
          in_remote_mode=0;
          monitor_cb=0;
        }
     }
  }
  else if(in_connect_command_mode)
  {
    if(data[0..0]!="\n")
      monitor_cb(data + "\n");
    else 
      monitor_cb("\n");
    monitor_cb(CONNECT_MENU_PROMPT);
  }
  else
  {
    if(catch(conn->write(data)))
    {
      monitor_cb("\n");
      monitor_cb("Connection to Pikon Server lost.\n");
      monitor_cb("\000ENDCONNECT");
      current_mode="";
      in_remote_mode=0;
      monitor_cb=0;
    }
  }
}

