#define ERROR(x) werror("SSH.packet: " + x + "\n")

inherit .mp;

object socket;

string incoming_enc_method;
string outgoing_enc_method;

string incoming_mac_method;
string outgoing_mac_method;

string incoming_compression_method;
string outgoing_compression_method;

int outgoing_sequence_number=0;
int incoming_sequence_number=0;

int local_mac_length=0;

int length_multiple=8;

int have_negotiated;

string compress(string data)
{
  return data;
}

string decompress(string data)
{
  return data;
}

string encrypt(string data)
{
  if(outgoing_enc_method=="none");

  return data;
}

string decrypt(string data)
{
  if(outgoing_enc_method=="none");

  return data;
}

string generate_mac(string data)
{
   return sprintf("%c", 0);
}

int verify_mac(string data, string mac)
{
   return 1;
}

string decode_binary_packet(string data)
{
  string payload,mac,padding;
  int packet_length, padding_length;
  
  // first, separate payload from mac checksum
  int res=sscanf(data, "%" + (sizeof(data)-local_mac_length)+ "s%" + local_mac_length + "c", payload, mac);
  if(res!=2) 
  {
    error("Incorrectly formatted packet. Unable to separate MAC from payload.");
  }
  if(have_negotiated && incoming_enc_method)
  {
    payload=decrypt(payload);
  }
  if(have_negotiated && incoming_mac_method)
  {
    verify_mac(payload, mac);
    incoming_sequence_number++;
  }

  // now, we get the packet length.
  res=sscanf(payload, "%4c%c%s", packet_length, padding_length, payload);
  if(res!=3) 
  {
    error("unable to extract packet/padding lengths from payload.");
  }
  ERROR("incoming packet_length: " + packet_length);  
  ERROR("incoming padding_length: " + padding_length);  

  // new we remove the padding from the payload.
  ERROR("total length of data: " + sizeof(payload));
  string fmt="%" + (packet_length-(1 + padding_length)) + "s%" + 
    padding_length + "s";

  res=sscanf(payload, fmt, payload, padding);
  if(res!=2)
  {
     error("unable to separate packet data from padding.");
  }

  if(have_negotiated && incoming_compression_method)
  { 
    payload=decompress(payload);
  }

// ERROR("decode_binary_packet: " + sprintf("%O", data));
  return payload;  

}

string generate_binary_packet(string data)
{
  int packet_length, padding_length;
  string padding,payload;
  string mac;

  if(have_negotiated && outgoing_compression_method)
  {
    data=compress(data);    
  }

  // figure out the padding
  int total_len=(5 + sizeof(data));  
  padding_length=length_multiple-(total_len%length_multiple);

  // we must have at least 4 bytes of padding.
  if(padding_length<4) padding_length=padding_length+length_multiple;

ERROR("outgoing padding length: " + padding_length);
ERROR("outgoing packet length: " + total_len);
  // we need a better way of getting padding_length random characters.
  padding=sprintf("%" + padding_length + "s", 
     Crypto.randomness.reasonably_random()->read(padding_length));
  

  payload= sprintf("%4c%c%s%s", total_len, padding_length, data, 
     padding);

  if(have_negotiated && outgoing_mac_method)
  {
    mac=generate_mac(payload);
  }
  else
  {
    mac=sprintf("%c", 0);
  }
  if(have_negotiated && outgoing_enc_method)
  {
    payload=encrypt(payload);  
    outgoing_sequence_number++;
  }

  return sprintf("%s%s", payload, mac);
}

int send(string data)
{
  return socket->write(generate_binary_packet(data));
}

string receive()
{
  return decode_binary_packet(socket->read());
}

string generate_string(string d)
{
   return sprintf("%4c%s", sizeof(d), d);
}

string push_string(string s, string d)
{
   d+=sprintf("%4c%s", sizeof(s), s);
   return d;
}

string push_boolean(int b, string d)
{
   d+=sprintf("%c", b);
   return d;
}

string push_uint32(int m, string d)
{
   d+=sprintf("%4c", m);
   return d;
}

string push_uint64(int m, string d)
{
   d+=sprintf("%8c", m);
   return d;
}

string push_mpint(object|int m, string d)
{
   string mp;
   mp=mp2string(m);
   return push_string(mp, d);
}

array pull_uint32(string d)
{
  int retval;
  if(sscanf(d, "%4c%s", retval, d) <1)
  {
    error("unable to pull uint32 from data.");
  }

  return ({retval, d});
}

array pull_uint64(string d)
{
  int retval;
  if(sscanf(d, "%8c%s", retval, d) <1)
  {
    error("unable to pull uint64 from data.");
  }

  return ({retval, d});
}

array pull_boolean(string d)
{
  int retval;
  if(sscanf(d, "%c%s", retval, d) <1)
  {
    error("unable to pull boolean from data.");
  }

  return ({retval, d});
}

array pull_mpint(string d)
{
   int retval;
   string s;
   [s, d]=pull_string(d);
   retval=string2mp(s);
   return ({retval, d});
}

array pull_string(string d)
{
  int len;
  string retval;
  if(sscanf(d, "%4c%s", len, d) !=2)
  {
    error("unable to read length of string from data.");
  }
  retval=d[0..(len-1)];

  if(sizeof(d)>len)
    d=d[len..];
  else d="";
  return ({retval, d});
}

