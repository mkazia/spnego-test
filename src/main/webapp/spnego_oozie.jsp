<%@ page language="java" import="java.io.IOException" %>
<%@ page language="java" import="org.apache.http.auth.AuthSchemeProvider" %>
<%@ page language="java" import="org.apache.http.auth.AuthScope" %>
<%@ page language="java" import="org.apache.http.auth.Credentials" %>
<%@ page language="java" import="org.apache.http.auth.KerberosCredentials" %>
<%@ page language="java" import="org.apache.http.client.config.AuthSchemes" %>
<%@ page language="java" import="org.apache.http.client.ClientProtocolException" %>
<%@ page language="java" import="org.apache.http.client.CredentialsProvider" %>
<%@ page language="java" import="org.apache.http.client.methods.CloseableHttpResponse" %>
<%@ page language="java" import="org.apache.http.client.methods.HttpGet" %>
<%@ page language="java" import="org.apache.http.client.methods.HttpPost" %>
<%@ page language="java" import="org.apache.http.config.Registry" %>
<%@ page language="java" import="org.apache.http.config.RegistryBuilder" %>
<%@ page language="java" import="org.apache.http.entity.ContentType" %>
<%@ page language="java" import="org.apache.http.entity.StringEntity" %>
<%@ page language="java" import="org.apache.http.HttpEntity" %>
<%@ page language="java" import="org.apache.http.impl.auth.SPNegoSchemeFactory" %>
<%@ page language="java" import="org.apache.http.impl.client.BasicCredentialsProvider" %>
<%@ page language="java" import="org.apache.http.impl.client.CloseableHttpClient" %>
<%@ page language="java" import="org.apache.http.impl.client.HttpClients" %>
<%@ page language="java" import="org.apache.http.util.EntityUtils" %>
<%@ page language="java" import="org.ietf.jgss.GSSCredential" %>
<html>
<head>
    <title>HTTP Client SPNEGO Example</title>
</head>
<body>
<%

    String oozieUrl = pageContext.getServletContext().getInitParameter("oozieUrl");
    GSSCredential creds = (GSSCredential)request.getAttribute("org.apache.catalina.realm.GSS_CREDENTIAL");

    if (null == creds) {
      out.print("No delegated credentials.");
      return;
    }
    out.print("Authenticating to Oozie as user: " + creds.getName().toString());

    CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
    credentialsProvider.setCredentials(AuthScope.ANY, new KerberosCredentials(creds));

    Registry<AuthSchemeProvider> authSchemeRegistry = RegistryBuilder
        .<AuthSchemeProvider> create()
        .register(AuthSchemes.SPNEGO, new SPNegoSchemeFactory(true)).build();

    CloseableHttpClient httpClient = HttpClients.custom()
        .setDefaultAuthSchemeRegistry(authSchemeRegistry)
        .setDefaultCredentialsProvider(credentialsProvider).build();

     out.print(checkOozieStatus(httpClient, oozieUrl));

     String submitJob = request.getParameter("submit");
     if (submitJob != null && submitJob.equals("true")) { %>
         <p><h3> Submitting Oozie Job, Job submit status: </h3>
         <%= runOozieJob(httpClient, oozieUrl, request.getRemoteUser()) %> <hr/><br/>
     <% }  %>
     <p><b>Click Submit button to submit an Oozie Job:</b>
     <form action="?" method="get">
     <input type="hidden" name="submit" value="true">
     <input type="submit" value="Submit">
     </form> <%

     httpClient.close();
%>
</body>
</html>

<%!
    private String checkOozieStatus(CloseableHttpClient httpClient, String oozieUrl) throws ClientProtocolException, IOException {

      HttpGet get = new HttpGet(oozieUrl + "/admin/status");
      CloseableHttpResponse oozieStatusResponse = httpClient.execute(get);

      String responseBody = null;
      int responseStatus;

      try {
        HttpEntity entity = oozieStatusResponse.getEntity();
        responseBody = EntityUtils.toString(entity);
        responseStatus = oozieStatusResponse.getStatusLine().getStatusCode();

        EntityUtils.consume(entity);

        StringBuffer sb = new StringBuffer();
        if (responseStatus < 300) {
           sb.append("<br/> Sucessfully Authenticated to Oozie");
        }
        sb.append("<br/>HTTP Status Code: " + responseStatus);
        sb.append("\n<br/>HTTP Status Message: " + responseBody);
        sb.append("<br/></hr>");
        return sb.toString();

      } finally {
        oozieStatusResponse.close();
      }
    }

    private String runOozieJob(CloseableHttpClient httpClient, String oozieUrl, String user) throws ClientProtocolException, IOException {
      HttpPost post = new HttpPost(oozieUrl + "/jobs?action=start");
      String xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n" +
          "<configuration>\n" +
          "<property><name>user.name</name><value>" + user + "</value></property>\n" +
          "<property><name>dryrun</name><value>False</value></property>\n" +
          "<property><name>oozie.use.system.libpath</name><value>True</value></property>\n" +
          "<property><name>output</name><value>here</value></property>\n" +
          "<property><name>input</name><value>/user/hue/oozie/workspaces/data/sonnets.txt</value></property>\n" +
          "<property><name>oozie.wf.application.path</name><value>/user/mkhdfsadmin/spark-workflow</value></property>\n" +
          "<property><name>nameNode</name><value>hdfs://ns1</value></property>\n" +
          "<property><name>jobTracker</name><value>yarnRM</value></property>\n" +
          "</configuration>\n";

      HttpEntity postEntity = new StringEntity(xml, ContentType.APPLICATION_XML);
      post.setEntity(postEntity);
      post.setEntity(postEntity);
      CloseableHttpResponse runResponse = httpClient.execute(post);

      String responseBody = null;
      int responseStatus;

      try {
        HttpEntity entity = runResponse.getEntity();
        responseBody = EntityUtils.toString(entity);
        responseStatus = runResponse.getStatusLine().getStatusCode();

        EntityUtils.consume(entity);

        StringBuffer sb = new StringBuffer();
        if (responseStatus < 300) {
           sb.append("<br/>Sucessfully Submitted Job to Oozie");
        }
        sb.append("<br/>HTTP Status Code: " + responseStatus);
        sb.append("\n<br/>HTTP Status Message: " + responseBody);
        return sb.toString();

      } finally {
        runResponse.close();
      }
    }
%>
