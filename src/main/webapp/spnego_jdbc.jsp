<%@ page language="java" import="java.sql.*" %>
<%@ page language="java" import="java.util.Properties" %>
<%@ page language="java" import="javax.security.auth.Subject" %>
<%@ page language="java" import="java.security.PrivilegedActionException" %>
<%@ page language="java" import="java.security.PrivilegedExceptionAction" %>
<%@ page language="java" import="com.sun.security.jgss.GSSUtil" %>
<%@ page language="java" import="org.ietf.jgss.*" %>

<html>
<head> <title> JDBC SPNEGO Auth Example with Credential Delegation</title> </head>
<body>

<%
    String jdbcUrl = pageContext.getServletContext().getInitParameter("jdbcUrl");
    GSSCredential creds = (GSSCredential)request.getAttribute("org.apache.catalina.realm.GSS_CREDENTIAL");
    Subject clientSubject = GSSUtil.createSubject(creds.getName(), creds);

    if (null == creds) {
        out.print("No delegated credentials.");
        return;
    }
    out.print("Running queries as user: " + creds.getName().toString());

    String searchCondition = request.getParameter("cond");
    if (searchCondition != null) { %>
        <p><h3> Search results for  <i> <%= searchCondition %> </i> </h3>
        <b> <%= runQuery(searchCondition, clientSubject, creds, jdbcUrl) %> </b> <hr/><br/>
    <% }  %>
    <p><b>Enter a search condition:</b>
    <form action="?" method="get">
    <input type="text" name="cond" size=30>
    <input type="submit" value="Search">
    </form>
</body>
</html>

<%! private String runQuery(final String cond, final Subject subject, final GSSCredential userCredential,
        final String jdbcUrl) throws SQLException {
    Connection conn = null;
    Statement stmt = null;
    ResultSet rset = null;
    try {
        DriverManager.registerDriver(new com.cloudera.impala.jdbc41.Driver());
        final Properties properties = new Properties();
        properties.put("userGSSCredential", userCredential);
        conn = Subject.doAs(subject, new PrivilegedExceptionAction<Connection>() {
            public Connection run() throws SQLException {
                return DriverManager.getConnection(jdbcUrl, properties);
            }
        });
        stmt = conn.createStatement();
        // query
        rset = stmt.executeQuery ("SELECT description, salary FROM sample_08 "+
                           (cond.equals("") ? "" : "WHERE " + cond ));
       return (formatResult(rset));
    } catch (PrivilegedActionException pae) {
        return ("<P> SQL error: <PRE> " + pae + " </PRE> </P>\n");
    } catch (SQLException se) {
        return ("<P> SQL error: <PRE> " + se + " </PRE> </P>\n");
    } finally {
        if (rset!= null) rset.close();
        if (stmt!= null) stmt.close();
        if (conn!= null) conn.close();
    }
}

private String formatResult(ResultSet rset) throws SQLException {
    StringBuffer sb = new StringBuffer();
    if (!rset.next())
        sb.append("<P> No matching rows.<P>\n");
    else {
        sb.append("<table border=\"1\" width=\"80%\">\n");
        sb.append("<tr>\n");
        sb.append("<th>Description</th>");
        sb.append("<th>Salary</th>\n");
        sb.append("</tr>\n");
        do {
            sb.append("<tr>\n");
            sb.append("<td>" + rset.getString(1) + "</td><td>" + rset.getInt(2) + "</td>\n");
            sb.append("</tr>\n");
        } while (rset.next());
    }
    return sb.toString();
}
%>
