#!/opt/pike/bin/pike -M. -I.

//
//  pikon: a console management system
//

#include <pikon.h>

constant version="0.1.0";

mapping prefs=([]);
mapping consoles=([]);
object listener;
string configfile="pikon.conf";

int main(int argc, array argv)
{
  int daemon_mode=0;

  array args=Getopt.find_all_options(argv, ({ 
      ({"pikonhome", Getopt.HAS_ARG, ({"-ph", "--pikonhome"}) }),
      ({"daemon", Getopt.NO_ARG, ({"-d", "--daemon"}) }),
      ({"configfile", Getopt.HAS_ARG, ({"-f", "--configfile"}) }) 
    }) );

  foreach(args, array arg)
  {
    if(arg[0]=="daemon")
      daemon_mode=1;
    else if(arg[0]=="pikonhome" && configfile=="")
      configfile=arg[1] + "/pikon.conf";
    else if(arg[0]=="configfile")
      configfile=arg[1];
  }

  if(daemon_mode)
  {
    catch(System.setsid());
  }
  load_preferences();
  call_out(start_console_listeners, 1);
  call_out(start_remote_listener, 1);
  return -1;

}

void load_preferences()
{
   string f=Stdio.read_file(configfile);
   if(!f) error("unable to read config file " + configfile + "\n");
   mapping p=.Config.read(f);
   prefs=p;
}

void start_console_listeners()
{
   if(!prefs || sizeof(indices(prefs))==0)
   {
     ERROR("no preferences!");
   }

   // let's look for all "console_*" preference entries.

   foreach(indices(prefs), string section)
   {
      if(section[0..7]=="console_")
      {
         // we have a console definition. let's make an object.
         string console_name=prefs[section]->name;
         consoles[console_name]=Pikon.console(console_name);
         consoles[console_name]->set_params(prefs[section]);
         consoles[console_name]->startup_connection();
      }
   }

}

void start_remote_listener()
{
    if(!prefs->remote_access)   
    {
       werror("No remote_access definition in preferences.\n"
	"Listener will not be started.\n");
       return;
    }
    else 
    {  
      int portnum;
      sscanf(prefs->remote_access->port, "%d", portnum); 
      werror("Starting remote listener on port " + portnum + "...");
      if(catch(listener=Pikon.remote_access(portnum, this_object())))
        werror(" failed.\n");
      else 
        werror(" successful.\n");
    }
}
