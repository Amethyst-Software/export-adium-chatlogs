<?xml version="1.0"?>

<!--
	TODO: Figure out xmins thing
-->

<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:adium="http://purl.org/net/ulf/ns/0.4-02"
	xmlns="http://www.w3.org/1999/xhtml"
	exclude-result-prefixes="adium">

	<xsl:output method="text" indent="yes" encoding="utf-8"/>
		
	<xsl:strip-space elements="*"/>

	<xsl:param name="title" select="'Chat'"/>

	<!-- Process chats -->
	<xsl:template match="adium:chat">{\rtf1\ansi\ansicpg1252\cocoartf1038\cocoasubrtf360
{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;\red128\green128\blue128;\red0\green0\blue128;\red0\green128\blue0;
\red0\green0\blue255;}
\margl1440\margr1440\vieww9000\viewh8400\viewkind0

<xsl:apply-templates/>

}
	</xsl:template>

	<!-- Process events -->
	<xsl:template match="adium:event">
		<xsl:text>\cf2 </xsl:text>
		<xsl:value-of select="@type"/>
		<xsl:text>: </xsl:text>
		<xsl:value-of select="translate(@time, 'T', ' ')"/>
		<xsl:text>\
</xsl:text>
	</xsl:template>

	<!-- Process messages -->
	<xsl:template match="adium:message">
		<!-- Record whether this is from the principal account -->
		<xsl:variable name="principal">
			<xsl:if test="@sender = /adium:chat/@account">
				<xsl:text>principal</xsl:text>
			</xsl:if>
		</xsl:variable>
		<!-- Process attributes -->
		<xsl:apply-templates select="@time"/>
		<xsl:choose>
			<xsl:when test="$principal != ''">
				<xsl:text>\cf4  </xsl:text>
			</xsl:when>
			<xsl:when test="$principal = ''">
				<xsl:text>\cf3  </xsl:text>
			</xsl:when>
		</xsl:choose>
		<xsl:apply-templates select="@alias"/>
		<xsl:text>:\cf0  </xsl:text>
		<xsl:apply-templates select="node()"/>
		<xsl:text>\
</xsl:text>
	</xsl:template>

	<xsl:template match="@sender|@alias">
		<xsl:if test="name() = 'alias' or not(../@alias)">
			<xsl:value-of select="."/>
		</xsl:if>
	</xsl:template>

	<xsl:template match="@time">
		<xsl:text>\cf2 </xsl:text>
		<xsl:value-of select="substring(., 12, 8)"/>
	</xsl:template>

	<xsl:template match="adium:message/@*" priority="0">
		<xsl:message>Unhandled attribute: message/@<xsl:value-of select="name()"/>&#10;</xsl:message>
	</xsl:template>

	<!-- Copy elements but strip off the namespace -->
	<xsl:template match="*">
		<xsl:element name="{local-name()}">
			<xsl:apply-templates select="node()|@*"/>
		</xsl:element>
	</xsl:template>

	<!-- Copy attributes but strip off the namespace -->
	<xsl:template match="@*">
		<xsl:attribute name="{local-name()}">
			<xsl:apply-templates/>
		</xsl:attribute>
	</xsl:template>

</xsl:stylesheet>
