int string2mp(string s)
{
  if(s=="") return 0;

  int mp=0;
  array rawbytes=({});
  array rb=({});
  int isneg=0;

  sscanf(s, "%{%c%}", rb);
  foreach(rb, mixed rb1)
    rawbytes+=rb1;
   int hashigh;
  if((int)rawbytes[0] & 0x80)
    hashigh=1;
  else hashigh=0;

  if((int)rawbytes[0]==0) // positive number with high bit set
  {
    rawbytes=rawbytes[1..];
  }
  else if(!hashigh); // high bit not set, so it must be a positive number
  else // we have a negative number.
  {
     isneg=1;
     int i,carry;
     carry=1;
     for(i=sizeof(rawbytes)-1; i>=0; i--) {
      if (carry)
      {
         if(rawbytes[i]==0)
         {
           rawbytes[i]=254;
           carry=1;
         }
         else
         {
           rawbytes[i]--;
           carry=0;
         }
      }
      rawbytes[i]^=0xff;

    }  
    

  }



  rawbytes=reverse(rawbytes);
  for(int i=0; i<sizeof(rawbytes); i++)
  {
    mp+=rawbytes[i]*(pow(256, i));
  }
  if(isneg) mp=0-mp;
  return mp;
}

string mp2string(object|int mp)
{
  if((int)mp==0)
  return "";
  string s;
  int x;
  string hex=sprintf("%x", abs((int)mp));
  if(sizeof(hex)%2)
    hex="0"+hex;
  
  array rawbytes=({0});
  array rb=({});

  sscanf(hex, "%{%2x%}", rb);
  foreach(rb, mixed rb1)
    rawbytes+=rb1;

  int hasnohigh;
  if((int)rawbytes[1] & 0x80)
    hasnohigh=0;
  else hasnohigh=1;

  if((int)mp<0)
  {

     int i,carry;
     carry=1;
     for(i=sizeof(rawbytes)-1; i>=0; i--) {
      rawbytes[i]^=0xff;
      if (carry)
      {
         if(rawbytes[i]==255)
         {
           rawbytes[i]=0;
           carry=1;
         }
         else
         {
           rawbytes[i]++;
           carry=0;
         }
      }
    }  
  }
  if(hasnohigh)
    rawbytes=rawbytes[1..];
  return sprintf("%{%c%}", rawbytes);
}

