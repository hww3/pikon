int twos_complement(int c)
{
  int neg=0;
  string h=sprintf("%x", c);
  werror("input: " + h + "\n");
  string h1="";
  int b,b1;

  if(h[0..0]=="-")
  {
     neg=1;
     h=h[1..];
  }
  else return c;
  
  if(sizeof(h)%2 == 1)
    h="0" + h;

  array bts=h/2;

  for(int i=0; i<sizeof(bts); i++)
  {
     sscanf(bts[i], "%x", b);
     b=b^255;
     h1+=sprintf("%x", b);
  }
  sscanf(h1, "%x", b1);
  b1++;
werror("output of 2c: " + sprintf("%x", b1) + "\n");
  return b1;
}

string format_mpint(int a)
{
  int b=twos_complement(a);
  string h1="";
  int neg=0;
    string h=sprintf("%x", b);

  if(h[0..0]=="-")
  {
    neg=1;
    h=h[1..];
  }
    if(sizeof(h)%2 == 1)
      h="0" + h;

    array bts=h/2;

    int x;
    sscanf(bts[0], "%x", x);
    if(!neg && x&128)  
    {
      h1="00";  
    }
    else if(neg && !(x&128))
    {
      x=x|128;
      bts[0]=sprintf("%x", x);
      sscanf(bts*"", "%x", b);
    }

  h1+=sprintf("%x", b);
  if(sizeof(h1)%2==1)
    h1="0" + h1;
  return h1;
}

