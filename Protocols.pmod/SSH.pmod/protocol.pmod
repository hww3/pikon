#define ERROR(x) werror("SSH.protocol: " + x + "\n")

#define SSH_MSG_DISCONNECT             1
#define SSH_MSG_IGNORE                 2
#define SSH_MSG_UNIMPLEMENTED          3
#define SSH_MSG_DEBUG                  4
#define SSH_MSG_SERVICE_REQUEST        5
#define SSH_MSG_SERVICE_ACCEPT         6

#define SSH_MSG_KEXINIT                20
#define SSH_MSG_NEWKEYS                21

/* Numbers 30-49 used for kex packets.
   Different kex methods may reuse message numbers in
   this range. */

#define SSH_MSG_KEXDH_INIT             30
#define SSH_MSG_KEXDH_REPLY            31

string implimentation_name="Pike-7.3";
string protocol_version="2.0";

inherit .packet;

string local_key;
string remote_key;

string local_key_type;
string remote_key_type;

string host_key_method;
string kex_method;

array supported_kex_methods=({"diffie-hellman-group1-sha1"});

array supported_enc_methods=({"3des-cbc", 
                              "aes192-cbc", 
                              "aes128-cbc", 
                              "arcfour",
                              "none"});

array supported_mac_methods=({"hmac-sha1",
                              "hmac-sha1-96",
                              "hmac-md5",
                              "hmac-md5-96",
                              "none"});

array supported_key_methods=({"ssh-dss",
                              "ssh-rsa"});

array supported_compression_methods=({"none"});

array supported_languages=({"en"});

string|int get_key_algorithm(array client, array server)
{
  foreach(client, string alg)
  {
    if(search(server, alg) !=-1)  // we have a mutually supported method.
    {
      // FIXME:
      // does this method require encryption capable hostkey?
      // does this method require signature capable hostkey?
      return alg;
    }
  }

  return 0;
}

string|int get_preferred_method(array client, array server)
{
  foreach(client, string alg)
  {
    if(search(server, alg)!=1) // we found a mutually agreeable method.
    {
      // FIXME:
      // does this method require encryption capable hostkey?
      // does this method require signature capable hostkey?
      return alg;
    }
  }
  return 0;
}

int client_negotiate()
{
  // first, send our list of preferred methods.
  
  string data="";
  data=sprintf("%c%16s",
     SSH_MSG_KEXINIT,
     Crypto.randomness.reasonably_random()->read(16));

  data=push_string(supported_kex_methods*",", data);
  data=push_string(supported_key_methods*",", data);
  data=push_string(supported_enc_methods*",", data);
  data=push_string(supported_enc_methods*",", data);
  data=push_string(supported_mac_methods*",", data);
  data=push_string(supported_mac_methods*",", data);
  data=push_string(supported_compression_methods*",", data);
  data=push_string(supported_compression_methods*",", data);
  data=push_string(supported_languages*",", data);
  data=push_string(supported_languages*",", data);
  data=push_boolean(0, data);
  data=push_uint32(0, data);
  
  send(data);

  data=receive();
  ERROR("got data!");

  int msg_type;
  
  int first_kex_packet_follows;

  string cookie,kex_algorithms,server_host_key_algorithms,
    encryption_algorithms_client_to_server,
    encryption_algorithms_server_to_client,
    mac_algorithms_client_to_server,
    mac_algorithms_server_to_client,
    compression_algorithms_client_to_server,
    compression_algorithms_server_to_client,
    languages_client_to_server,
    languages_server_to_client="";

  int res=sscanf(data, "%c%16s%s", msg_type, cookie, data);
  if(res!=3)
  {
    error("badly formatted algorithm negotiation packet.");
  }

  if(msg_type!=SSH_MSG_KEXINIT)
  {
    error("expecting SSH_MSG_KEXINIT, got " + msg_type);
  }
  [kex_algorithms,data]=pull_string(data);
  [server_host_key_algorithms,data]=pull_string(data);
  [encryption_algorithms_client_to_server,data]=pull_string(data);
  [encryption_algorithms_server_to_client,data]=pull_string(data);
  [mac_algorithms_client_to_server,data]=pull_string(data);
  [mac_algorithms_server_to_client,data]=pull_string(data);
  [compression_algorithms_client_to_server,data]=pull_string(data);
  [compression_algorithms_server_to_client,data]=pull_string(data);
  [languages_client_to_server,data]=pull_string(data);
  [languages_server_to_client,data]=pull_string(data);
   
  // okay, we have our preferred choices and we have theirs.
  // let's compare notes and make some decisions.  
    
  kex_method=get_key_algorithm(supported_kex_methods, kex_algorithms/",");

  if(!kex_method)
  {
    socket->close();
    error("unable to negotiate key exchange method with remote.");
  }  

  host_key_method=get_preferred_method(supported_key_methods, server_host_key_algorithms/",");
  if(!host_key_method)
  {
    socket->close();
    error("unable to negotiate host key method with remote.");
  }  

  incoming_enc_method=get_preferred_method(supported_enc_methods, 
    encryption_algorithms_server_to_client/",");
  outgoing_enc_method=get_preferred_method(supported_enc_methods, 
    encryption_algorithms_client_to_server/",");
  if(!(incoming_enc_method && outgoing_enc_method))
  {
    socket->close();
    error("unable to negotiate encryption methods with remote.");
  }

  incoming_mac_method=get_preferred_method(supported_mac_methods, 
    mac_algorithms_server_to_client/",");
  outgoing_mac_method=get_preferred_method(supported_mac_methods, 
    mac_algorithms_client_to_server/",");
  if(!(incoming_mac_method && outgoing_mac_method))
  {
    socket->close();
    error("unable to negotiate MAC methods with remote.");
  }

  incoming_compression_method=get_preferred_method(supported_compression_methods, 
    compression_algorithms_server_to_client/",");
  outgoing_compression_method=get_preferred_method(supported_compression_methods, 
   compression_algorithms_client_to_server/",");
  if(!(incoming_compression_method && outgoing_compression_method))
  {
    socket->close();
    error("unable to negotiate compression methods with remote.");
  }

  [first_kex_packet_follows, data]=pull_boolean(data);

  // is the other end going to try to guess our preference?
  // we should really handle this properly.
  if(first_kex_packet_follows)
  {
     ERROR("other end sent a kex guess.");
     error("we don't know how to handle key exchange guesses.");
  }

  do_kex_client();

}


array do_kex_client()
{
  
  return ({sharedsecret, exhash});
}
