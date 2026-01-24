<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <xsl:output omit-xml-declaration="yes" indent="no"/>
  <xsl:template match="/">
    <xsl:for-each select="*">
      <xsl:call-template name="element-template">
        <xsl:with-param name="root" select="true()" />
      </xsl:call-template>
    </xsl:for-each>
  </xsl:template>
  <xsl:template name="element-template">
    <xsl:param name="root" />
    <xsl:value-of select="concat('{&quot;tag&quot;:&quot;', name(), '&quot;')" />
    <xsl:if test="$root">
      <xsl:text>, &quot;namespaces&quot;:{</xsl:text>
      <xsl:for-each select="namespace::node()[name()!='xml']">
        <xsl:value-of select="concat('&quot;', name(current()), '&quot;:&quot;', current(), '&quot;')" />
        <xsl:if test="position() != last()">
          <xsl:text>,</xsl:text>
        </xsl:if>
      </xsl:for-each>
      <xsl:text>}</xsl:text>
    </xsl:if>
    <xsl:if test="@*">
      <xsl:text>, &quot;attributes&quot;:{</xsl:text>
      <xsl:for-each select="@*">
        <xsl:value-of select="concat('&quot;', name(), '&quot;:&quot;', ., '&quot;')" />
        <xsl:if test="position() != last()">
          <xsl:text>,</xsl:text>
        </xsl:if>
      </xsl:for-each>
      <xsl:text>}</xsl:text>
    </xsl:if>
    <xsl:if test="*">
      <xsl:text>, &quot;children&quot;:[</xsl:text>
      <xsl:for-each select="*">
        <xsl:call-template name="element-template" />
        <xsl:if test="position() != last()">
          <xsl:text>,</xsl:text>
        </xsl:if>
      </xsl:for-each>
      <xsl:text>]</xsl:text>
    </xsl:if>
    <xsl:if test="text()">
      <xsl:text>,&quot;innerText&quot;: &quot;</xsl:text>
      <xsl:choose>
        <xsl:when test="contains(text(), '&quot;')">
          <xsl:call-template name="replace">
            <xsl:with-param name="text" select="text()" />
            <xsl:with-param name="replace" select="'&quot;'" />
            <xsl:with-param name="by" select="'\&quot;'" />
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="text()"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>&quot;</xsl:text>
    </xsl:if>
    <xsl:text>}</xsl:text>
  </xsl:template>
  <xsl:template name="replace">
    <xsl:param name="text" />
    <xsl:param name="replace" />
    <xsl:param name="by" />
    <xsl:choose>
      <xsl:when test="contains($text, $replace)">
        <xsl:value-of select="substring-before($text,$replace)" />
        <xsl:value-of select="$by" />
        <xsl:call-template name="replace">
          <xsl:with-param name="text"
          select="substring-after($text,$replace)" />
          <xsl:with-param name="replace" select="$replace" />
          <xsl:with-param name="by" select="$by" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
