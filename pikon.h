#ifdef DEBUG
#define werror(x) werror(x)
#else
#define werror(x) 
#endif

#define ERROR(x) Stdio.stderr.write((ctime(time())-"\n") + ": " + x + "\n")

#define CLIENT_HELP_MESSAGE "\n"\
  "Welcome to the Pikon Client. Available Commands Are:\n"\
  "open          Open a connection to a Pikon server\n"\
  "login         Login as a valid user to a connected server\n"\
  "logout        De-authenticate a previously logged in user\n"\
  "monitor       Open a read-only session to a console\n"\
  "connect       Open a read-write console session\n"\
  "listconsoles  List available consoles\n"\
  "showlog       Display today's logfile for a console\n"\
  "connect       Open a read-write console session\n"\
  "quit          End the Pikon client session\n"

#define CONNECT_MENU_OPTIONS "\n\n"\
  "Connect Options Menu\n"\
  "Press one of the following keys:\n\n"\
  "q          End this CONNECT session\n"\
  "x          Close this menu and return to session\n"\
  "b          Send BREAK\n"

#define CONNECT_MENU_PROMPT "ConnectOptions> "
