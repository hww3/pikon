#include <pikon.h>
array connections=({});

object main_program;
object listener;

void create(int port, object this)
{
  main_program=this;
  listener=Stdio.Port();
  if(!listener->bind(port, incoming_connection_accept))
  {
    werror("Unable to bind to port " + port+ ".");
  }
}

void incoming_connection_accept()
{
   object conn=listener->accept();
   ERROR("incoming connection from " + conn->query_address());
   handle_remote_connection(this_object(), conn);
}

void handle_remote_connection(object this, object rconn)
{
//   werror("sizeof connections: " + sizeof(connections) + "\n");
   object conn=Pikon.RemoteConnection(rconn, this);
   conn->notify_on_close(lambda(){connections-=({conn});});
   connections+=({conn});
}

