object connection;
string host;
int port;

int read_cb_set, write_cb_set, close_cb_set, connect_cb_set, connected;
function close_cb1, connect_cb1, read_cb, write_cb;

void create(string h, int p)
{
  host=h;
  port=p;
  read_cb_set=0;
  write_cb_set=0;
  connected=0;

  connection=Stdio.File();
  connect();
}

void connect()
{
  connection->async_connect(host, port, connect_cb);  
}

void connect_cb(int success)
{
  if(success)
  {
    connected=1;    
    connection->set_nonblocking();
    if(write_cb && !write_cb_set)
    {
      connection->set_write_callback(write_cb);    
      write_cb_set=1;
    }
    if(read_cb && !read_cb_set)
    {
      connection->set_read_callback(read_cb);    
      read_cb_set=1;
    }
    if(close_cb && !close_cb_set)
    {
      connection->set_close_callback(close_cb);
      close_cb_set=1;
    }
    if(connect_cb1 && !connect_cb_set)
    {
      connect_cb1();
      connect_cb_set=1;
    }
  }

  else
  {
    call_out(connect, 60, host, port);
  }
}

int set_connect_callback(function cb)
{
  connect_cb1=cb;
  read_cb_set=1;
}

int set_read_callback(function cb)
{
  read_cb=cb;
  if(connected && read_cb_set)
  {
    connection->set_read_callback(read_cb);
    read_cb_set=1;
  }
}

int set_write_callback(function cb)
{
  write_cb=cb;
  if(connected && write_cb_set)
  {
    connection->set_write_callback(write_cb);
    write_cb_set=1;
  }
}

int set_close_callback(function cb)
{
  close_cb1=cb;
  if(connected && close_cb_set)
  {
    connection->set_close_callback(close_cb);
    close_cb_set=1;
  }
}

void close_cb(int id)
{
  if(close_cb1) close_cb1(id);
  connect_cb_set=0;
  read_cb_set=0;
  write_cb_set=0;
  close_cb_set=0;

  werror("connection closed for " + host + ":" + port + ". will attempt "
    "reconnect in 60 seconds.\n");
  connect();  
}
