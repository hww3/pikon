// 
//  Pikon.console: class for handling consoles.
//

#include <pikon.h>

string console_name;
mapping params;
object con, logfile;
int onnewline=1;

mapping logfileopened;

array monitors=({});

array writers=({});

object log=ADT.History(30);

void create(string name)
{
  console_name=name;
}

int set_params(mapping p)
{
  if(!check_params(p)) return 0;
  params=p;
  return 1;
}

int startup_connection()
{
  werror("starting console " + console_name);
  if(params->type=="serial")
  {
    if(catch(con=Pikon.Serial_console(params->device)))
      werror("error starting serial console for " + console_name + ".");
  }
  else if(params->type=="telnet")
  {
    if(catch(con=Pikon.Telnet_console(params->host, params->port)))
      werror("error starting telnet console for " + console_name + ".");
  }
  else if(params->type=="ssl")
  {
    if(catch(con=Pikon.SSL_console(params->host, params->port)))
      werror("error starting ssl console for " + console_name + ".");
  }
  else
  {
     ERROR("unknown terminal type " + params->type + " for console " + console_name);

  }

  if(params->log)
  {
    open_logfile();
  }

  con->set_read_callback(read_console);
  con->set_write_callback(write_console);
  con->set_connect_callback(connect_console);
  con->set_close_callback(close_console);
  con->connect();
}

void open_logfile()
{
  werror("called open_logfile.");
  mixed f;
  f=file_stat(params->logdir);
  if(objectp(f) && f->isdir)
  {
    int now=time();
    mixed t=localtime(now);
    string logfile_name=params->name + "_" + 
      sprintf("%4d%02d%02d", (1900+t->year), (t->mon+1),t->mday) + ".log";
    
    f=file_stat(params->logdir + "/" + logfile_name);
    if(!objectp(f))
    {
      if(catch(logfile=Stdio.File(params->logdir + "/" + logfile_name, "crw")))
        ERROR("unable to create logfile " + params->logdir + "/" + logfile_name);
      else
      {
        logfileopened=t;
        werror("console " + console_name + ": logfile created");
        write_newstamp();
      }
    }
    else
    {
      logfile=Stdio.File(params->logdir + "/" + logfile_name, "rw");
      if(catch(logfile=Stdio.File(params->logdir + "/" + logfile_name, "rw")))
        ERROR("unable to create logfile " + params->logdir + "/" + logfile_name);
      else
      {
        logfile->seek(-1);
        werror("console " + console_name + ": logfile reopened");
        logfileopened=t;
        write_timestamp();
      }
    }
  }
  else
  {
    ERROR("log file directory " + params->logdir + " does not exist or "
      "is not a directory.");
  }
}

void close_logfile()
{
  werror("called close logfile");
  mixed f;
  f=file_stat(params->logdir);
  if(objectp(f) && f->isdir)
  {
    write_endstamp();
    logfile->close();
    werror("console " + console_name + ": logfile closed");
    logfile=0;
    return;
  }
  else
  {
    ERROR("log file directory " + params->logdir + " does not exist or "
      "is not a directory.");
    return;
  }
}

void write_logfile(string data, int|void logonly)
{
    if(!logfile) return;
    int now=time();
    mixed t=localtime(now);
    if(t->mday != logfileopened->mday) // logfile is not from today
    {
      werror("Logfile is not this hour...");
      close_logfile();
      werror("Done closing, opening new one...");
      open_logfile();
    }
    low_write_logfile(data, logonly);
}

void low_write_logfile(string data, int|void logonly)
{
    array d=data/"\n";
    int now=time();

    for(int i=0; i<sizeof(d); i++)
    { 
      string d1=d[i];      
      if(onnewline) d[i]=(ctime(now)-"\n") + " *| " + d[i];
      if(i+1 == (sizeof(d)-1) && d[i+1]=="") 
      {
        onnewline=1;      
        d[i]+="\n";
        d1+="\n";
     
      }
      else if(i+1<(sizeof(d)-1)) 
      {
        onnewline=1;      
        d[i]+="\n";
        d1+="\n";
      }
      else onnewline=0;
      if(!logonly) 
	log->push(d1);
      if(params->log && objectp(logfile))
        logfile->write(d[i]);
    }
}

int check_params(mapping p)
{
  return 1;
}

void read_console(int id, string data)
{
  foreach(monitors, function f)
    f(data);
  foreach(writers, function f)
    f(data);
  data=replace(data, ({"\013", "\010"}), ({"\n", "\n"}));
  write_logfile(data);
}

void connect_console(int id, string data)
{
  ERROR("console " + console_name + ": connection opened");
}

void close_console(int id, string data)
{
  ERROR("console " + console_name + ": connection closed");
}

void write_console(int id)
{
  werror("console " + console_name + ": write");
}

void monitor(function f, string name)
{
  foreach(values(log), string l)
    f(l);

  monitors+=({f});
}

mixed connectrw(function f, string name)
{
//  if(sizeof(writers)!=0) return 0; // we can only have one writing session. 
  call_out(lambda(){  foreach(values(log), string l) f(l);writers=({f});}, 1);
  call_out(test_writers, 20);
  return con_write;
}

private void test_writers()
{
  remove_call_out(test_writers);
  if(writers==({})) return;
  foreach(writers, function w)
  {
    if(catch(w("\000ALIVE?")))
    {
      writers-=({w});
    }
  }
  call_out(test_writers, 20);
}

private void con_write(mixed data)
{
  con->write(data);
}

void nomonitor(function f, string name)
{
  monitors-=({f});
}

void noconnectrw(function f, string name)
{
  writers-=({f});
}

void write_timestamp()
{
     write_logfile("Log File Timestamp \n", 1);
     remove_call_out(write_timestamp);
     call_out(write_timestamp, 3600);
}

void write_newstamp()
{
     write_logfile("Log File Begins \n", 1);
     remove_call_out(write_timestamp);
     call_out(write_timestamp, 3600);
}

void write_endstamp()
{
     low_write_logfile("Log File Ends \n", 1);
     remove_call_out(write_timestamp);
     call_out(write_timestamp, 3600);
}



