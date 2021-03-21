<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:template match="/">
<html>
  <head></head>
  <body style="font-family: arial;">
    <br/>
    <form method="get">
      <input type="hidden" name="action" value="search"/>
      xml <input type="checkbox" name="xml" value="1"/>
      <xsl:text> </xsl:text><input type="text" name="address" value="{/root/search}"/>
      <xsl:text> </xsl:text><input type="submit" value="Поиск"/>
    </form>
    
    <xsl:if test="/root/all_count = 0">
      <div style="color:red;font-weight:bold;">Not found</div>
    </xsl:if>

    <xsl:if test="/root/all_count &gt; count(/root/logs/item)">
      <div style="color:red;font-weight:bold;">I found <xsl:value-of  select="/root/all_count"/> strings, but show only <xsl:value-of select="count(/root/logs/item)"/></div>
    </xsl:if>

    <xsl:for-each select="/root/logs/item">
      <div style="padding-top:10px;">
        <div>
          <strong><xsl:value-of select="created"/></strong>
        </div>
        <div>
          <xsl:value-of select="str"/>
        </div>
      </div> 
    </xsl:for-each>

    <xsl:if test="/root/bench">
      <div style="color:green;">
        <pre><xsl:value-of  select="/root/bench"/></pre>
      </div>
    </xsl:if>

  </body>
</html>
</xsl:template>

</xsl:stylesheet>
