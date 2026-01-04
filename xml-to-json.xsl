<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <xsl:output omit-xml-declaration="yes" indent="no"/>
  <xsl:template match="/">
    <xsl:for-each select="*">
      <xsl:call-template name="element-template" />
    </xsl:for-each>
  </xsl:template>
  <xsl:template name="element-template">
    <xsl:value-of select="concat('{&quot;tag&quot;:&quot;', name(), '&quot;, &quot;attributes&quot;:{')" />
    <xsl:for-each select="@*">
      <xsl:value-of select="concat('&quot;', name(), '&quot;:&quot;', ., '&quot;')" />
      <xsl:if test="position() != last()">
        <xsl:text>,</xsl:text>
      </xsl:if>
    </xsl:for-each>
    <xsl:text>}, &quot;children&quot;:[</xsl:text>
    <xsl:for-each select="*">
      <xsl:call-template name="element-template" />
      <xsl:if test="position() != last()">
        <xsl:text>,</xsl:text>
      </xsl:if>
    </xsl:for-each>
    <xsl:text>],</xsl:text>
    <xsl:text>&quot;innerText&quot;: &quot;</xsl:text>
    <xsl:value-of select="translate(., '&quot;', '‽')" />
    <xsl:text>&quot;}</xsl:text>
  </xsl:template>
</xsl:stylesheet>
