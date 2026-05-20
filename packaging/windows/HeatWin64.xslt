<?xml version="1.0" encoding="UTF-8"?>
<!-- Post-heat: Win64 on harvested components; drop CentralLogger.exe (owned by Product.wxs). -->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:wi="http://schemas.microsoft.com/wix/2006/wi">
  <xsl:output omit-xml-declaration="yes" indent="yes" />

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <!-- Main exe is installed via MainExecutable in Product.wxs (avoids ICE30 duplicate). -->
  <xsl:template match="wi:Component[wi:File[contains(@Source, 'CentralLogger.exe')]]" />

  <xsl:template match="wi:Component">
    <xsl:copy>
      <xsl:apply-templates select="@*" />
      <xsl:attribute name="Win64">yes</xsl:attribute>
      <xsl:apply-templates select="node()" />
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
