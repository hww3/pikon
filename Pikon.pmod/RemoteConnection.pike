#include <pikon.h>

object conn;
object this;
function close_cb;
function write_cb;

int in_command_mode=1;

string remote_address="";
string current_mode="";
string read_buff="";
string write_buff="";
string current_mode_console="";

void create(object rconn, object t)
{
  conn=rconn;
  this=t;
  handle_remote_connection();
}

void handle_remote_connection()
{
   conn->set_blocking();
   send_response(200, "Pikon Server " + this->main_program->version + " ready.");
   remote_address=conn->query_address();
   conn->set_nonblocking();
   conn->set_read_callback(read_remote_connection);
   conn->set_write_callback(write_remote_connection);
   conn->set_close_callback(remote_has_closed);
}

void read_remote_connection(mixed id, mixed data)
{
  if(in_command_mode) read_remote_command(data);
  else read_console_connection(data);
}

void read_async_connect_mode()
{
  if(in_command_mode) return; // we don't want to keep going in command mode.
  mixed d=conn->read(1024,1); // read any data available.
  if(d) read_console_connection(d);
  call_out(read_async_connect_mode, 0);
}

void read_console_connection(string data)
{
  if(data[0..0]=="\000")
  {  
    data=replace(data,({"\r", "\n"}),({"", ""}));
    if(data=="\000ENDMONITOR")
      parse_command("ENDMONITOR");
    if(data=="\000ENDCONNECT")
      parse_command("ENDCONNECT");
  }
  else if(write_cb)
  {
    write_cb(data);
  }
}

void read_remote_command(string data)
{
  data=replace(data, "\r", "");
  if((data-"\n")=="")
  return; 
  if(sizeof(write_buff)>0)
  {
    data=write_buff+data;
    write_buff="";
  }
  if(search(data, "\n")==-1)  
  {
     // we still don't have a full command.
     write_buff=data;
  }
  else
  {
    array c=(data/"\n")-({""});
    parse_command(c[0]);
    if(sizeof(c)>1)
    {
      data=c[1..]*"\n";
      read_remote_command(data);
    }
  }
}

void parse_command(string cmd)
{ 
   array c;
   werror("received command -->" + cmd + "<--\n");
   switch(lower_case((cmd/" ")[0]))
   {
     case "quit":
     case "logout":
     send_response(200, "Goodbye.");
     conn->close();
     remote_has_closed();
     break;

     case "version":
     send_response(210, "Pikon v" + this->main_program->version);
     break;

     case "listconsoles":
     send_response(212, "Available consoles follow");
     list_consoles();

     case "showlog":

     c=cmd/" ";
     if(sizeof(c)==2)
     {
       string con=lower_case(c[1]);
       if(this->main_program->consoles && !this->main_program->consoles[con])
       {
         send_response(325, "non-existant console");
       }
       else if(!has_permission(con))
       {
         send_response(326, "insufficient permissions");
       } 
       else
       {
         send_response(212, "Most recent log follows");
         show_log(con);
       }
     }
     break;

     case "endmonitor":
     if(!in_command_mode)
     {
         string con;
         con=current_mode_console;
    ERROR("MONITOR session from " + remote_address + " to " + current_mode_console + " closed.");

         this->main_program->consoles[con]->nomonitor(send_data_to_remote, conn->query_address());
         send_response(239, "MONITOR connection to console " + 
            this->main_program->prefs["console_" + con]->name  + 
            " closed.");
         current_mode="";
         in_command_mode=1;
     }
     break;

     case "endconnect":
     if(!in_command_mode)
     {
         string con;
         con=current_mode_console;
    ERROR("CONNECT session from " + remote_address + " to " + current_mode_console + " closed.");
         this->main_program->consoles[
con]->noconnectrw(send_data_to_remote, conn->query_address());
         send_response(239, "CONNECT connection to console " + 
            this->main_program->prefs["console_" + con]->name  + 
            " closed.");
         current_mode="";
         in_command_mode=1;
         write_cb=0;
     }
     break;
   
     case "monitor":
     c=cmd/" ";
     if(sizeof(c)==2)
     {
       string con=lower_case(c[1]);
       if(this->main_program->consoles && !this->main_program->consoles[con])
       {
         send_response(325, "non-existant console");
       }
       else if(!has_permission(con))
       {
         send_response(326, "insufficient permissions");
       } 
       else
       {
         send_response(240, "Connection to console " + 
               this->main_program->prefs["console_" + con]->name + 
               " opened in MONITOR mode.");
         in_command_mode=0;
         current_mode="monitor";
         current_mode_console=con;
         this->main_program->consoles[con]->monitor(send_data_to_remote, conn->query_address());
    ERROR("MONITOR session from " + remote_address + " to " + current_mode_console + " opened.");
       }
     }
     else
     {
       send_response(320, "invalid command format");
     }
     break;

     case "connect":
     c=cmd/" ";
     if(sizeof(c)==2)
     {
       string con=lower_case(c[1]);
       if(this->main_program->consoles && !this->main_program->consoles[con])
       {
         send_response(325, "non-existant console");
       }
       else if(!has_write_permission(con))
       {
         send_response(326, "insufficient permissions");
       } 
       else
       {
         
 
         if(write_cb=this->main_program->consoles[con]->connectrw(
           send_data_to_remote, conn->query_address()))
         {
    ERROR("CONNECT session from " + remote_address + " to " + current_mode_console + " opened.");
           send_response(240, "Connection to console " + 
               this->main_program->prefs["console_" + con]->name + 
               " opened in CONNECT mode.");
           in_command_mode=0;
           current_mode="connect";
           call_out(read_async_connect_mode, 0);
           current_mode_console=con;
         }
         else
         {
           send_response(324, "console is already in use.");
           break;
         }
       }
     }
     else
     {
       send_response(320, "invalid command format");
     }
     break;
   
     default:
     send_response(300, "command not implimented");
     break;
   }
}

void write_remote_connection(mixed id)
{

}

void close_remote_connection(mixed id)
{
  ERROR("remote connection from " + remote_address + " closed.");
}

void send_response(int code, string response, void|string data)
{
  werror(sprintf("%d %s\r\n", code, response));
  conn->write(sprintf("%d %s\r\n", code, response));
  if(data)
    write_body(data);
  return;
}

void write_body(string s)
{
    s=replace(s,"\r","");
    foreach(s/"\n",string line)
      {
        if(strlen(line) && line[0]=='.')
          line="."+line+"\r\n";
        else
          line=line+"\r\n";
        if(conn->write(line) != strlen(line))
          error("Pikon.remote_access: Failed to write body.\n");
      }
    conn->write(".\r\n");
}

void notify_on_close(function f)
{
  close_cb=f;
}

void remote_has_closed()
{
  if(!in_command_mode && current_mode=="connect")
  {  
    ERROR("CONNECT session from " + remote_address + " to " + current_mode_console + " closed.");
    string con;
    con=current_mode_console;
    this->main_program->consoles[
      con]->noconnectrw(send_data_to_remote, conn->query_address());
    send_response(239, "CONNECT connection to console " + 
      this->main_program->prefs["console_" + con]->name  + 
      " closed.");
    in_command_mode=1;
    write_cb=0;
  } 
  else if(!in_command_mode && current_mode=="monitor")
  {
     string con;
     con=current_mode_console;
     this->main_program->consoles[con]->nomonitor(send_data_to_remote, conn->query_address());
    ERROR("MONITOR session from " + remote_address + " to " + current_mode_console + " closed.");
     send_response(239, "MONITOR connection to console " + 
            this->main_program->prefs["console_" + con]->name  + 
            " closed.");
     current_mode="";
     in_command_mode=1;
   }

  if(close_cb && functionp(close_cb)) close_cb();
  close_remote_connection(0); 
}

int has_permission(string con)
{
  return 1;
}

int has_write_permission(string con)
{
  return 1;
}

void send_data_to_remote(mixed data)
{
  conn->write(data);
}

void show_log(string c)
{
  string d="";
  if(!this->main_program->consoles[c])
    d="unable to find console " + c + ".";
  else
  {
     d=this->main_program->consoles[c]->get_log();
  }
  conn->write(d + "\r\n.\r\n");
}

void list_consoles()
{
  string d="";
  foreach(indices(this->main_program->consoles), string con)
    d+=" " + sprintf("%O", 
this->main_program->consoles[con]->console_name) +"\n";

  conn->write(d + "\r\n.\r\n");
}
