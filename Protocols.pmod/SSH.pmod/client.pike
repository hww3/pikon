#define ERROR(x) werror("SSH.client: " + x + "\n")
inherit .protocol;

string remote_protocol_version;
string remote_implimentation_name;

object socket;

void create(string host, int port)
{
  string read_buf;
  socket=Stdio.File();
  int r=socket->connect(host, port);
  if(!r)
  {
    error("Unable to connect to remote host " + host + " port " + port +".");
  }
  // first, send our identification, no more than 255 characters in length.
  ERROR("connected!");
  string ident="SSH-" + protocol_version +  "-" +
    implimentation_name;
  if(sizeof(ident)>253) ident=ident[0..252];
  socket->write(ident + "\r\n");
  ERROR("sent ident...");
  // now, we read the remote's identification, ignoring any lines
  // that don't start with SSH-.

  do
  {
    read_buf=socket->read(1024,1);
    ERROR("read line from remote: " + read_buf);
  }
  while(read_buf[0..3]!="SSH-");
  ERROR("Read remote ident: " + read_buf);  
  // line endings are unimportant to us.
  read_buf=replace(read_buf, ({"\r", "\n"}), ({"", ""}));

  array remote_ident=read_buf/"-";
  if(sizeof(remote_ident) != 3)
  {
    error("Remote is not an SSH server.");
  }
  else if(remote_ident[1] !="2.0" && remote_ident[1] !="1.99")
  {
    error("Remote server runs an unsupported version " + remote_ident[1]);
  }
 
  remote_protocol_version=remote_ident[1];
  remote_implimentation_name=remote_ident[2]; 
  
  client_negotiate();  
}
