<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx"
  xmlns:edm="http://docs.oasis-open.org/odata/ns/edm" xmlns:json="http://json.org/"
>
  <!--
    This style sheet transforms OData 4.0 CSDL XML documents into OpenAPI 2.0 or OpenAPI 3.0.0 JSON

    Latest version: https://github.com/oasis-tcs/odata-openapi/blob/master/tools/V4-CSDL-to-OpenAPI.xsl

    TODO:
    - 3.0.0
    - - anyOf:[null,$ref] for nullable single-valued navigation properties,
    - operation descriptions for entity sets and singletons
    - custom headers and query options - https://issues.oasis-open.org/browse/ODATA-1099
    - response codes and descriptions - https://issues.oasis-open.org/browse/ODATA-884
    - Inline definitions for Edm.* to make OpenAPI documents self-contained
    - securityDefinitions script parameter with default
    "securityDefinitions":{"basic_auth":{"type":"basic","description": "Basic
    Authentication"}}
    - Validation annotations -> minimum, maximum, exclusiveM??imum,
    see https://github.com/oasis-tcs/odata-vocabularies/blob/master/vocabularies/Org.OData.Validation.V1.md,
    inline and explace style
    - complex or collection-valued function parameters need special treatment in /paths,
    use parameter aliases with alias option of type string
    - @Extends for entity container: include /paths from referenced container
    - both "clickable" and freestyle $expand, $select, $orderby - does not work yet, open issue for Swagger UI
    - system query options for actions/functions/imports depending on "Collection("
    - 200 response for PATCH
    - ETag for GET / If-Match for PATCH and DELETE depending on @Core.OptimisticConcurrency
    - allow external targeting for @Core.Description similar to @Common.Label
    - reduce duplicated code in /paths production
    - header sap-message for V2 services from SAP in 20x responses
  -->

  <xsl:output method="text" indent="yes" encoding="UTF-8" omit-xml-declaration="yes" />
  <xsl:strip-space elements="*" />


  <xsl:param name="scheme" select="'http'" />
  <xsl:param name="host" select="'localhost'" />
  <xsl:param name="basePath" select="'/service-root'" />

  <xsl:param name="info-title" select="null" />
  <xsl:param name="info-description" select="null" />
  <xsl:param name="info-version" select="null" />

  <xsl:param name="externalDocs-url" select="null" />
  <xsl:param name="externalDocs-description" select="null" />

  <xsl:param name="property-longDescription" select="true()" />

  <xsl:param name="x-tensions" select="null" />

  <xsl:param name="odata-version" select="'4.0'" />
  <xsl:param name="diagram" select="null" />
  <xsl:param name="references" select="null" />
  <xsl:param name="top-example" select="50" />

  <xsl:param name="odata-schema" select="'https://raw.githubusercontent.com/oasis-tcs/odata-openapi/master/examples/odata-definitions.json'" />
  <xsl:param name="swagger-ui" select="'http://localhost/swagger-ui'" />
  <!--
    <xsl:param name="swagger-ui-major-version" select="'2'" />
  -->
  <xsl:param name="openapi-formatoption" select="''" />
  <xsl:param name="openapi-version" select="'2.0'" />

  <xsl:variable name="reuse-schemas">
    <xsl:choose>
      <xsl:when test="$openapi-version='2.0'">
        <xsl:text>#/definitions/</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>#/components/schemas/</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="reuse-parameters">
    <xsl:choose>
      <xsl:when test="$openapi-version='2.0'">
        <xsl:text>#/parameters/</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>#/components/parameters/</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="coreNamespace" select="'Org.OData.Core.V1'" />
  <xsl:variable name="coreAlias"
    select="//edmx:Include[@Namespace=$coreNamespace]/@Alias|//edm:Schema[@Namespace=$coreNamespace]/@Alias" />
  <xsl:variable name="coreDescription" select="concat($coreNamespace,'.Description')" />
  <xsl:variable name="coreDescriptionAliased">
    <xsl:choose>
      <xsl:when test="$coreAlias">
        <xsl:value-of select="concat($coreAlias,'.Description')" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="'Core.Description'" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="coreLongDescription" select="concat($coreNamespace,'.LongDescription')" />
  <xsl:variable name="coreLongDescriptionAliased">
    <xsl:choose>
      <xsl:when test="$coreAlias">
        <xsl:value-of select="concat($coreAlias,'.LongDescription')" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="'Core.LongDescription'" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="capabilitiesNamespace" select="'Org.OData.Capabilities.V1'" />
  <xsl:variable name="capabilitiesAlias"
    select="//edmx:Include[@Namespace=$capabilitiesNamespace]/@Alias|//edm:Schema[@Namespace=$capabilitiesNamespace]/@Alias" />
  <xsl:variable name="validationNamespace" select="'Org.OData.Validation.V1'" />
  <xsl:variable name="validationAlias"
    select="//edmx:Include[@Namespace=$validationNamespace]/@Alias|//edm:Schema[@Namespace=$validationNamespace]/@Alias" />

  <xsl:variable name="commonNamespace" select="'com.sap.vocabularies.Common.v1'" />
  <xsl:variable name="commonAlias"
    select="//edmx:Include[@Namespace=$commonNamespace]/@Alias|//edm:Schema[@Namespace=$commonNamespace]/@Alias" />
  <xsl:variable name="commonLabel" select="concat($commonNamespace,'.Label')" />
  <xsl:variable name="commonLabelAliased" select="concat($commonAlias,'.Label')" />
  <xsl:variable name="commonQuickInfo" select="concat($commonNamespace,'.QuickInfo')" />
  <xsl:variable name="commonQuickInfoAliased" select="concat($commonAlias,'.QuickInfo')" />

  <xsl:variable name="defaultResponse">
    <xsl:text>"default":{"$ref":"#/</xsl:text>
    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>components/</xsl:text>
    </xsl:if>
    <xsl:text>responses/error"}</xsl:text>
  </xsl:variable>

  <xsl:template name="Core.Description">
    <xsl:param name="node" />
    <xsl:variable name="description"
      select="$node/edm:Annotation[(@Term=$coreDescription or @Term=$coreDescriptionAliased) and not(@Qualifier)]/@String
             |$node/edm:Annotation[(@Term=$coreDescription or @Term=$coreDescriptionAliased) and not(@Qualifier)]/edm:String" />
    <xsl:call-template name="escape">
      <xsl:with-param name="string" select="normalize-space($description)" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="Core.LongDescription">
    <xsl:param name="node" />
    <xsl:variable name="description"
      select="$node/edm:Annotation[(@Term=$coreLongDescription or @Term=$coreLongDescriptionAliased) and not(@Qualifier)]/@String|$node/edm:Annotation[(@Term=$coreLongDescription or @Term=$coreLongDescriptionAliased) and not(@Qualifier)]/edm:String" />
    <xsl:call-template name="escape">
      <xsl:with-param name="string" select="$description" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="Core-Annotation">
    <xsl:param name="node" />
    <xsl:param name="term" />
    <xsl:call-template name="escape">
      <xsl:with-param name="string"
        select="$node/edm:Annotation[(@Term=concat('Org.OData.Core.V1.',$term) or @Term=concat($coreAlias,'.',$term)) and not(@Qualifier)]/@String
               |$node/edm:Annotation[(@Term=concat('Org.OData.Core.V1.',$term) or @Term=concat($coreAlias,'.',$term)) and not(@Qualifier)]/edm:String" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="Common.Label">
    <xsl:param name="node" />
    <xsl:variable name="label"
      select="normalize-space($node/edm:Annotation[(@Term=$commonLabel or @Term=$commonLabelAliased) and not(@Qualifier)]/@String|$node/edm:Annotation[(@Term=$commonLabel or @Term=$commonLabelAliased) and not(@Qualifier)]/edm:String)" />
    <xsl:variable name="explaceLabel">
      <xsl:choose>
        <xsl:when test="local-name($node)='Property'">
          <xsl:variable name="target" select="concat(../../@Alias,'.',../@Name,'/',@Name)" />
          <xsl:value-of
            select="//edm:Annotations[@Target=$target and not(@Qualifier)]/edm:Annotation[@Term=(@Term=$commonLabel or @Term=$commonLabelAliased) and not(@Qualifier)]/@String" />
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$label">
        <xsl:call-template name="escape">
          <xsl:with-param name="string" select="$label" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="escape">
          <xsl:with-param name="string" select="$explaceLabel" />
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="Common.QuickInfo">
    <xsl:param name="node" />
    <xsl:variable name="label"
      select="normalize-space($node/edm:Annotation[(@Term=$commonQuickInfo or @Term=$commonQuickInfoAliased) and not(@Qualifier)]/@String|$node/edm:Annotation[(@Term=$commonQuickInfo or @Term=$commonQuickInfoAliased) and not(@Qualifier)]/edm:String)" />
    <xsl:variable name="explaceLabel">
      <xsl:choose>
        <xsl:when test="local-name($node)='Property'">
          <xsl:variable name="target" select="concat(../../@Alias,'.',../@Name,'/',@Name)" />
          <xsl:value-of
            select="//edm:Annotations[@Target=$target and not(@Qualifier)]/edm:Annotation[@Term=(@Term=$commonQuickInfo or @Term=$commonQuickInfoAliased) and not(@Qualifier)]/@String" />
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$label">
        <xsl:call-template name="escape">
          <xsl:with-param name="string" select="$label" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="escape">
          <xsl:with-param name="string" select="$explaceLabel" />
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:variable name="key-as-segment"
    select="//edm:EntityContainer/edm:Annotation[(@Term='Org.OData.Core.V1.KeyAsSegment' or @Term=concat($coreAlias,'.KeyAsSegment')) and not(@Qualifier)]" />

  <xsl:template match="edmx:Edmx">
    <!--
      <xsl:message><xsl:value-of select="$commonAlias"/></xsl:message>
      <xsl:message><xsl:value-of select="$commonNamespace"/></xsl:message>
    -->
    <xsl:text>{</xsl:text>
    <xsl:choose>
      <xsl:when test="$openapi-version='2.0'">
        <xsl:text>"swagger":"2.0"</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>"openapi":"3.0.0"</xsl:text>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:text>,"info":{"title":"</xsl:text>
    <xsl:variable name="schemaDescription">
      <xsl:call-template name="Core.Description">
        <xsl:with-param name="node" select="//edm:Schema" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="containerDescription">
      <xsl:call-template name="Core.Description">
        <xsl:with-param name="node" select="//edm:EntityContainer" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$info-title">
        <xsl:value-of select="$info-title" />
      </xsl:when>
      <xsl:when test="$schemaDescription!=''">
        <xsl:value-of select="$schemaDescription" />
      </xsl:when>
      <xsl:when test="$containerDescription!=''">
        <xsl:value-of select="$containerDescription" />
      </xsl:when>
      <xsl:when test="//edm:EntityContainer">
        <xsl:text>OData Service for namespace </xsl:text>
        <xsl:value-of select="//edm:EntityContainer/../@Namespace" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>OData CSDL Document for namespace </xsl:text>
        <xsl:value-of select="//edm:Schema/@Namespace" />
      </xsl:otherwise>
    </xsl:choose>

    <xsl:text>","version":"</xsl:text>
    <xsl:choose>
      <xsl:when test="$info-version">
        <xsl:value-of select="$info-version" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="Core-Annotation">
          <xsl:with-param name="node" select="//edm:Schema" />
          <xsl:with-param name="term" select="'SchemaVersion'" />
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:text>","description":"</xsl:text>
    <xsl:variable name="schemaLongDescription">
      <xsl:call-template name="Core-Annotation">
        <xsl:with-param name="node" select="//edm:Schema" />
        <xsl:with-param name="term" select="'LongDescription'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="containerLongDescription">
      <xsl:call-template name="Core-Annotation">
        <xsl:with-param name="node" select="//edm:EntityContainer" />
        <xsl:with-param name="term" select="'LongDescription'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$info-description">
        <xsl:value-of select="$info-description" />
      </xsl:when>
      <xsl:when test="$schemaLongDescription!=''">
        <xsl:value-of select="$schemaLongDescription" />
      </xsl:when>
      <xsl:when test="$containerLongDescription!=''">
        <xsl:value-of select="$containerLongDescription" />
      </xsl:when>
      <xsl:when test="//edm:EntityContainer">
        <xsl:text>This OData service is located at [</xsl:text>
        <xsl:value-of select="$scheme" />
        <xsl:text>://</xsl:text>
        <xsl:value-of select="$host" />
        <xsl:value-of select="$basePath" />
        <xsl:text>/](</xsl:text>
        <xsl:value-of select="$scheme" />
        <xsl:text>://</xsl:text>
        <xsl:value-of select="$host" />
        <xsl:call-template name="replace-all">
          <xsl:with-param name="string">
            <xsl:call-template name="replace-all">
              <xsl:with-param name="string" select="$basePath" />
              <xsl:with-param name="old" select="'('" />
              <xsl:with-param name="new" select="'%28'" />
            </xsl:call-template>
          </xsl:with-param>
          <xsl:with-param name="old" select="')'" />
          <xsl:with-param name="new" select="'%29'" />
        </xsl:call-template>
        <xsl:text>/)</xsl:text>
      </xsl:when>
    </xsl:choose>
    <xsl:if test="$diagram">
      <xsl:apply-templates select="//edm:EntityType|//edm:ComplexType" mode="description" />
    </xsl:if>
    <xsl:if test="$references">
      <xsl:apply-templates select="//edmx:Include" mode="description" />
    </xsl:if>
    <xsl:text>"}</xsl:text>

    <xsl:if test="$externalDocs-url">
      <xsl:text>,"externalDocs":{</xsl:text>
      <xsl:if test="$externalDocs-description">
        <xsl:text>"description":"</xsl:text>
        <xsl:value-of select="$externalDocs-description" />
        <xsl:text>",</xsl:text>
      </xsl:if>
      <xsl:text>"url":"</xsl:text>
      <xsl:value-of select="$externalDocs-url" />
      <xsl:text>"}</xsl:text>
    </xsl:if>

    <xsl:if test="$x-tensions">
      <xsl:text>,</xsl:text>
      <xsl:value-of select="$x-tensions" />
    </xsl:if>

    <xsl:if test="//edm:EntityContainer">
      <xsl:choose>
        <xsl:when test="$openapi-version='2.0'">
          <xsl:text>,"schemes":["</xsl:text>
          <xsl:value-of select="$scheme" />
          <xsl:text>"],"host":"</xsl:text>
          <xsl:value-of select="$host" />
          <xsl:text>","basePath":"</xsl:text>
          <xsl:value-of select="$basePath" />
          <xsl:text>"</xsl:text>

          <!-- TODO: Capabilities.SupportedFormats -->
          <xsl:text>,"consumes":["application/json"]</xsl:text>
          <xsl:text>,"produces":["application/json"]</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>,"servers":[{"url":"</xsl:text>
          <xsl:value-of select="$scheme" />
          <xsl:text>://</xsl:text>
          <xsl:value-of select="$host" />
          <xsl:value-of select="$basePath" />
          <xsl:text>"}]</xsl:text>
        </xsl:otherwise>
      </xsl:choose>

    </xsl:if>

    <xsl:apply-templates select="//edm:EntitySet|//edm:Singleton" mode="tags" />

    <!-- paths is required, so we need it also for documents that do not define an entity container -->
    <xsl:text>,"paths":{</xsl:text>
    <xsl:apply-templates select="//edm:EntityContainer" mode="paths" />
    <xsl:text>}</xsl:text>

    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>,"components":{</xsl:text>
    </xsl:if>

    <xsl:apply-templates select="//edm:EntityType|//edm:ComplexType|//edm:TypeDefinition|//edm:EnumType|//edm:EntityContainer"
      mode="hash"
    >
      <xsl:with-param name="name">
        <xsl:choose>
          <xsl:when test="$openapi-version='2.0'">
            <xsl:text>definitions</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>schemas</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:with-param>
      <xsl:with-param name="after" select="$openapi-version='2.0'" />
    </xsl:apply-templates>

    <xsl:if test="//edm:EntityContainer">
      <xsl:text>,"parameters":{</xsl:text>
      <xsl:text>"top":{"name":"$top","in":"query","description":"Show only the first n items</xsl:text>
      <xsl:text>, see [OData Paging - Top](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374630)",</xsl:text>
      <xsl:call-template name="parameter-type">
        <xsl:with-param name="type" select="'integer'" />
        <xsl:with-param name="plus" select="',&quot;minimum&quot;:0'" />
      </xsl:call-template>
      <xsl:if test="number($top-example) and $openapi-version!='2.0'">
        <xsl:text>,"example":</xsl:text>
        <xsl:value-of select="$top-example" />
      </xsl:if>
      <xsl:text>},</xsl:text>
      <xsl:text>"skip":{"name":"$skip","in":"query","description":"Skip the first n items</xsl:text>
      <xsl:text>, see [OData Paging - Skip](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374631)",</xsl:text>
      <xsl:call-template name="parameter-type">
        <xsl:with-param name="type" select="'integer'" />
        <xsl:with-param name="plus" select="',&quot;minimum&quot;:0'" />
      </xsl:call-template>
      <xsl:text>},</xsl:text>
      <xsl:choose>
        <xsl:when test="$odata-version='4.0'">
          <xsl:text>"count":{"name":"$count","in":"query","description":"Include count of items</xsl:text>
          <xsl:text>, see [OData Count](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374632)",</xsl:text>
          <xsl:call-template name="parameter-type">
            <xsl:with-param name="type" select="'boolean'" />
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>"count":{"name": "$inlinecount","in":"query","description":"Include count of items</xsl:text>
          <xsl:text>, see [OData Count](http://www.odata.org/documentation/odata-version-2-0/uri-conventions/#InlinecountSystemQueryOption)",</xsl:text>
          <xsl:call-template name="parameter-type">
            <xsl:with-param name="type" select="'string'" />
            <xsl:with-param name="plus">
              <xsl:text>,"enum":["allpages","none"]</xsl:text>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>},</xsl:text>
      <xsl:text>"filter":{"name":"$filter","in":"query","description":"Filter items by property values</xsl:text>
      <xsl:text>, see [OData Filtering](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374625)",</xsl:text>
      <xsl:call-template name="parameter-type">
        <xsl:with-param name="type" select="'string'" />
      </xsl:call-template>
      <xsl:text>}</xsl:text>
      <xsl:if test="$odata-version='4.0'">
        <xsl:text>,"search":{"name":"$search","in":"query","description":"Search items by search phrases</xsl:text>
        <xsl:text>, see [OData Searching](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374633)",</xsl:text>
        <xsl:call-template name="parameter-type">
          <xsl:with-param name="type" select="'string'" />
        </xsl:call-template>
        <xsl:text>}</xsl:text>
      </xsl:if>
      <xsl:text>}</xsl:text>

      <xsl:text>,"responses":{"error":{"description":"Error",</xsl:text>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>"content":{"application/json":{</xsl:text>
      </xsl:if>
      <xsl:text>"schema":{"$ref":"</xsl:text>
      <xsl:value-of select="$reuse-schemas" />
      <xsl:text>odata.error"}</xsl:text>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>}}</xsl:text>
      </xsl:if>
      <xsl:text>}}</xsl:text>
    </xsl:if>

    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>}</xsl:text>
    </xsl:if>

    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template name="parameter-type">
    <xsl:param name="type" />
    <xsl:param name="plus" select="null" />

    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>"schema":{</xsl:text>
    </xsl:if>
    <xsl:text>"type":"</xsl:text>
    <xsl:value-of select="$type" />
    <xsl:text>"</xsl:text>

    <xsl:if test="$plus">
      <xsl:value-of select="$plus" />
    </xsl:if>

    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>}</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- definitions for standard error response - only needed if there's an entity container -->
  <xsl:template match="edm:EntityContainer" mode="hashpair">
    <xsl:text>"odata.error":{"type":"object","required":["error"],"properties":{"error":{"$ref":"</xsl:text>
    <xsl:value-of select="$reuse-schemas" />
    <xsl:text>odata.error.main"}}}</xsl:text>
    <xsl:text>,"odata.error.main":{"type":"object","required":["code","message"],"properties":{"code":{"type":"string"},"message":</xsl:text>
    <xsl:choose>
      <xsl:when test="$odata-version='4.0'">
        <xsl:text>{"type":"string"},"target":{"type":"string"},"details":</xsl:text>
        <xsl:text>{"type":"array","items":{"$ref":"</xsl:text>
        <xsl:value-of select="$reuse-schemas" />
        <xsl:text>odata.error.detail"}}</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>{"$ref":"</xsl:text>
        <xsl:value-of select="$reuse-schemas" />
        <xsl:text>odata.error.message"}</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>,"innererror":{"type":"object","description":"The structure of this object is service-specific"}}}</xsl:text>
    <xsl:choose>
      <xsl:when test="$odata-version='4.0'">
        <xsl:text>,"odata.error.detail":{"type":"object","required":["code","message"],"properties":{"code":{"type":"string"},"message":{"type":"string"},"target":{"type":"string"}}}</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>,"odata.error.message":{"type":"object","required":["lang","value"],"properties":{"lang":{"type":"string"},"value":{"type":"string"}}}</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="edm:EntityType|edm:ComplexType" mode="description">
    <xsl:if test="position() = 1">
      <xsl:text>\n\n## Entity Data Model\n![ER Diagram](http://yuml.me/diagram/class/</xsl:text>
    </xsl:if>
    <xsl:if test="position() > 1">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="@BaseType" mode="description" />
    <xsl:text>[</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:if test="local-name()='EntityType'">
      <xsl:text>{bg:orange}</xsl:text>
    </xsl:if>
    <xsl:text>]</xsl:text>
    <xsl:apply-templates select="edm:NavigationProperty|edm:Property" mode="description" />
    <xsl:if test="position() = last()">
      <xsl:text>)</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="@BaseType" mode="description">
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="." />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="type">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="." />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:text>[</xsl:text>
    <xsl:choose>
      <xsl:when test="$qualifier=../../@Namespace or $qualifier=../../@Alias">
        <xsl:value-of select="$type" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="@Type" />
        <xsl:text>{bg:whitesmoke}</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>]^</xsl:text>
  </xsl:template>

  <xsl:template match="edm:NavigationProperty|edm:Property" mode="description">
    <xsl:variable name="singleType">
      <xsl:choose>
        <xsl:when test="starts-with(@Type,'Collection(')">
          <xsl:value-of select="substring-before(substring-after(@Type,'('),')')" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@Type" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="collection" select="starts-with(@Type,'Collection(')" />
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="$singleType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="type">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="$singleType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="nullable">
      <xsl:call-template name="nullableFacetValue">
        <xsl:with-param name="type" select="@Type" />
        <xsl:with-param name="nullableFacet" select="@Nullable" />
      </xsl:call-template>
    </xsl:variable>
    <!--
      TODO: evaluate Partner to just have one arrow
      [FeaturedProduct]<0..1-0..1>[Advertisement]
    -->
    <xsl:if test="$qualifier!='Edm' or local-name='NavigationProperty'">
      <xsl:text>,[</xsl:text>
      <xsl:value-of select="../@Name" />
      <xsl:text>]-</xsl:text>
      <xsl:choose>
        <xsl:when test="$collection">
          <xsl:text>*</xsl:text>
        </xsl:when>
        <xsl:when test="$nullable">
          <xsl:text>0..1</xsl:text>
        </xsl:when>
      </xsl:choose>
      <xsl:text>>[</xsl:text>
      <xsl:choose>
        <xsl:when test="$qualifier=../../@Namespace or $qualifier=../../@Alias">
          <xsl:value-of select="$type" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$singleType" />
          <xsl:text>{bg:whitesmoke}</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>]</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="edmx:Include" mode="description">
    <xsl:if test="position() = 1">
      <xsl:text>\n\n## References</xsl:text>
    </xsl:if>
    <xsl:text>\n- [</xsl:text>
    <xsl:value-of select="@Namespace" />
    <xsl:text>](</xsl:text>
    <xsl:choose>
      <xsl:when test="substring(@Namespace,1,10)='Org.OData.'">
        <xsl:text>https://github.com/oasis-tcs/odata-vocabularies/blob/master/vocabularies/</xsl:text>
        <xsl:value-of select="@Namespace" />
        <xsl:text>.md</xsl:text>
      </xsl:when>
      <xsl:when test="substring(@Namespace,1,21)='com.sap.vocabularies.'">
        <xsl:text>https://wiki.scn.sap.com/wiki/display/EmTech/OData+4.0+Vocabularies+-+SAP+</xsl:text>
        <xsl:value-of select="substring(@Namespace,22,string-length(@Namespace)-24)" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$swagger-ui" />
        <xsl:text>/?url=</xsl:text>
        <xsl:call-template name="replace-all">
          <xsl:with-param name="string">
            <xsl:call-template name="json-url">
              <xsl:with-param name="url" select="../@Uri" />
            </xsl:call-template>
          </xsl:with-param>
          <xsl:with-param name="old" select="')'" />
          <xsl:with-param name="new" select="'%29'" />
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="edm:EnumType" mode="hashpair">
    <xsl:text>"</xsl:text>
    <xsl:value-of select="../@Namespace" />
    <xsl:text>.</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>":{"type":"string",</xsl:text>
    <xsl:text>"enum":[</xsl:text>
    <xsl:apply-templates select="edm:Member" mode="enum" />
    <xsl:text>]</xsl:text>
    <xsl:call-template name="title-description">
      <xsl:with-param name="fallback-title" select="@Name" />
    </xsl:call-template>
    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:Member" mode="enum">
    <xsl:if test="position() > 1">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:text>"</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>"</xsl:text>
  </xsl:template>

  <xsl:template match="edm:TypeDefinition" mode="hashpair">
    <xsl:text>"</xsl:text>
    <xsl:value-of select="../@Namespace" />
    <xsl:text>.</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>":{</xsl:text>
    <xsl:call-template name="type">
      <xsl:with-param name="type" select="@UnderlyingType" />
      <xsl:with-param name="nullableFacet" select="'false'" />
    </xsl:call-template>
    <xsl:call-template name="title-description">
      <xsl:with-param name="fallback-title" select="@Name" />
    </xsl:call-template>
    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:EntityType|edm:ComplexType" mode="hashpair">
    <xsl:text>"</xsl:text>
    <xsl:value-of select="../@Namespace" />
    <xsl:text>.</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>":{</xsl:text>

    <xsl:if test="@BaseType">
      <xsl:text>"allOf":[{</xsl:text>
      <xsl:call-template name="schema-ref">
        <xsl:with-param name="qualifiedName" select="@BaseType" />
      </xsl:call-template>
      <xsl:text>},{</xsl:text>
    </xsl:if>

    <xsl:text>"type":"object"</xsl:text>

    <xsl:apply-templates select="edm:Property|edm:NavigationProperty" mode="hash">
      <xsl:with-param name="name" select="'properties'" />
    </xsl:apply-templates>

    <xsl:call-template name="title-description">
      <xsl:with-param name="fallback-title" select="@Name" />
    </xsl:call-template>

    <xsl:if test="@BaseType">
      <xsl:text>}]</xsl:text>
    </xsl:if>
    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:Property|edm:NavigationProperty" mode="hashvalue">
    <xsl:call-template name="type">
      <xsl:with-param name="type" select="@Type" />
      <xsl:with-param name="nullableFacet" select="@Nullable" />
    </xsl:call-template>
    <xsl:choose>
      <xsl:when test="local-name()='Property'">
        <xsl:apply-templates select="*[local-name()!='Annotation']" mode="list2" />
      </xsl:when>
      <xsl:otherwise>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="title-description" />
  </xsl:template>

  <xsl:template name="nullableFacetValue">
    <xsl:param name="type" />
    <xsl:param name="nullableFacet" />
    <xsl:choose>
      <xsl:when test="$nullableFacet">
        <xsl:value-of select="$nullableFacet" />
      </xsl:when>
      <xsl:when test="starts-with($type,'Collection(')">
        <xsl:value-of select="'false'" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="'true'" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="type">
    <xsl:param name="type" />
    <xsl:param name="nullableFacet" />
    <xsl:param name="inParameter" select="false()" />
    <xsl:variable name="noArray" select="$inParameter" />
    <xsl:variable name="nullable">
      <xsl:call-template name="nullableFacetValue">
        <xsl:with-param name="type" select="$type" />
        <xsl:with-param name="nullableFacet" select="$nullableFacet" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="collection" select="starts-with($type,'Collection(')" />
    <xsl:variable name="singleType">
      <xsl:choose>
        <xsl:when test="$collection">
          <xsl:value-of select="substring-before(substring-after($type,'('),')')" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$type" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="$singleType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="simpleName">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="$singleType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="$collection">
      <xsl:if test="$odata-version='2.0'">
        <xsl:text>"title":"Collection of </xsl:text>
        <xsl:value-of select="$simpleName" />
        <xsl:text>","type":"object","properties":{"results":{</xsl:text>
      </xsl:if>
      <xsl:text>"type":"array","items":{</xsl:text>
    </xsl:if>
    <xsl:choose>
      <!--
        <xsl:when test="$singleType='Edm.Stream'">
        <xsl:call-template name="nullableType">
        <xsl:with-param name="type" select="'string'" />
        <xsl:with-param name="nullable" select="$nullable" />
        <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"base64url","title":"Edm.Stream"</xsl:text>
        </xsl:when>
      -->
      <xsl:when test="$singleType='Edm.String'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'string'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:apply-templates select="@MaxLength" />
        <xsl:call-template name="Validation.AllowedValues" />
        <xsl:call-template name="Validation.Pattern" />
      </xsl:when>
      <xsl:when test="$singleType='Edm.Binary'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'string'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"base64url"</xsl:text>
        <xsl:apply-templates select="@MaxLength" />
      </xsl:when>
      <xsl:when test="$singleType='Edm.Boolean'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'boolean'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Decimal'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type">
            <xsl:choose>
              <xsl:when test="$odata-version='2.0'">
                <xsl:value-of select="'string'" />
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="'number,string'" />
              </xsl:otherwise>
            </xsl:choose>
          </xsl:with-param>
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"decimal"</xsl:text>
        <xsl:choose>
          <xsl:when test="not(@Scale) or @Scale='0'">
            <xsl:text>,"multipleOf":1</xsl:text>
          </xsl:when>
          <xsl:when test="@Scale!='variable'">
            <xsl:text>,"multipleOf":1.0e-</xsl:text>
            <xsl:value-of select="@Scale" />
          </xsl:when>
        </xsl:choose>
        <xsl:if test="@Precision">
          <xsl:variable name="scale">
            <xsl:choose>
              <xsl:when test="not(@Scale)">
                <xsl:value-of select="0" />
              </xsl:when>
              <xsl:when test="@Scale='variable'">
                <xsl:value-of select="0" />
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@Scale" />
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          <xsl:variable name="limit">
            <xsl:call-template name="repeat">
              <xsl:with-param name="string" select="'9'" />
              <xsl:with-param name="count" select="@Precision - $scale" />
            </xsl:call-template>
            <xsl:if test="$scale > 0">
              <xsl:text>.</xsl:text>
              <xsl:call-template name="repeat">
                <xsl:with-param name="string" select="'9'" />
                <xsl:with-param name="count" select="$scale" />
              </xsl:call-template>
            </xsl:if>
          </xsl:variable>
          <xsl:if test="@Precision &lt; 16">
            <xsl:text>,"minimum":-</xsl:text>
            <xsl:value-of select="$limit" />
            <xsl:text>,"maximum":</xsl:text>
            <xsl:value-of select="$limit" />
            <xsl:if test="not($inParameter)">
              <xsl:text>,"example":</xsl:text>
              <xsl:value-of select="$limit" />
            </xsl:if>
          </xsl:if>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Byte'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'integer'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"uint8"</xsl:text>
      </xsl:when>
      <xsl:when test="$singleType='Edm.SByte'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'integer'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"int8"</xsl:text>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Int16'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'integer'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"int16"</xsl:text>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Int32'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'integer'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"int32"</xsl:text>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Int64'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type">
            <xsl:choose>
              <xsl:when test="$odata-version='2.0'">
                <xsl:value-of select="'string'" />
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="'integer,string'" />
              </xsl:otherwise>
            </xsl:choose>
          </xsl:with-param>
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"int64"</xsl:text>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Date'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'string'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$odata-version='2.0'">
            <xsl:if test="not($inParameter)">
              <xsl:text>,"example":"/Date(1492041600000)/"</xsl:text>
            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>,"format":"date"</xsl:text>
            <xsl:if test="not($inParameter)">
              <xsl:text>,"example":"2017-04-13"</xsl:text>
            </xsl:if>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Double'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'number,string'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"double"</xsl:text>
        <xsl:if test="not($inParameter)">
          <xsl:text>,"example":3.14</xsl:text>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Single'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'number,string'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"float"</xsl:text>
        <xsl:if test="not($inParameter)">
          <xsl:text>,"example":3.14</xsl:text>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Guid'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'string'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"uuid"</xsl:text>
        <xsl:if test="not($inParameter)">
          <xsl:text>,"example":"01234567-89ab-cdef-0123-456789abcdef"</xsl:text>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$singleType='Edm.DateTimeOffset'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'string'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$odata-version='2.0'">
            <xsl:if test="not($inParameter)">
              <xsl:text>,"example":"/Date(1492098664000)/"</xsl:text>
            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>,"format":"date-time"</xsl:text>
            <xsl:if test="not($inParameter)">
              <xsl:text>,"example":"2017-04-13T15:51:04Z"</xsl:text>
            </xsl:if>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="$singleType='Edm.TimeOfDay'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'string'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$odata-version='2.0'">
            <xsl:if test="not($inParameter)">
              <xsl:text>,"example":"PT15H51M04S"</xsl:text>
            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>,"format":"time"</xsl:text>
            <xsl:if test="not($inParameter)">
              <xsl:text>,"example":"15:51:04"</xsl:text>
            </xsl:if>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="$singleType='Edm.Duration'">
        <xsl:call-template name="nullableType">
          <xsl:with-param name="type" select="'string'" />
          <xsl:with-param name="nullable" select="$nullable" />
          <xsl:with-param name="noArray" select="$noArray" />
        </xsl:call-template>
        <xsl:text>,"format":"duration"</xsl:text>
        <xsl:if test="not($inParameter)">
          <xsl:text>,"example":"P4DT15H51M04.217S"</xsl:text>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$qualifier='Edm'">
        <xsl:text>"$ref":"</xsl:text>
        <xsl:value-of select="$odata-schema" />
        <xsl:text>#/definitions/</xsl:text>
        <xsl:value-of select="$singleType" />
        <xsl:text>"</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="ref">
          <xsl:with-param name="qualifier" select="$qualifier" />
          <xsl:with-param name="name">
            <xsl:call-template name="substring-after-last">
              <xsl:with-param name="input" select="$singleType" />
              <xsl:with-param name="marker" select="'.'" />
            </xsl:call-template>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:apply-templates select="@MaxLength" />
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="@DefaultValue">
      <xsl:with-param name="type" select="$singleType" />
    </xsl:apply-templates>
    <xsl:if test="$collection">
      <xsl:if test="$odata-version='2.0'">
        <xsl:text>}}</xsl:text>
      </xsl:if>
      <xsl:text>}</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="Validation.Pattern">
    <xsl:variable name="pattern"
      select="edm:Annotation[@Term=concat($validationNamespace,'.Pattern') or @Term=concat($validationAlias,'.Pattern')]/@String|edm:Annotation[@Term=concat($validationNamespace,'.Pattern') or @Term=concat($validationAlias,'.Pattern')]/edm:String" />
    <xsl:if test="$pattern!=''">
      <xsl:text>,"pattern":"</xsl:text>
      <xsl:value-of select="$pattern" />
      <xsl:text>"</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="Validation.AllowedValues">
    <xsl:variable name="allowedValues"
      select="edm:Annotation[(@Term=concat($validationNamespace,'.AllowedValues') or @Term=concat($validationAlias,'.AllowedValues')) and not(@Qualifier)]" />
    <xsl:if test="$allowedValues">
      <xsl:text>,"enum":[</xsl:text>
      <xsl:apply-templates select="$allowedValues/edm:Collection/edm:Record" mode="Validation.AllowedValues" />
      <xsl:text>]</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="edm:Record" mode="Validation.AllowedValues">
    <xsl:if test="position()>1">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:text>"</xsl:text>
    <xsl:value-of select="edm:PropertyValue[@Property='Value']/@String|edm:PropertyValue[@Property='Value']/edm:String" />
    <xsl:text>"</xsl:text>
  </xsl:template>

  <xsl:template name="ref">
    <xsl:param name="qualifier" />
    <xsl:param name="name" />
    <xsl:variable name="internalNamespace" select="//edm:Schema[@Alias=$qualifier]/@Namespace" />
    <xsl:variable name="externalNamespace">
      <xsl:choose>
        <xsl:when test="//edmx:Include[@Alias=$qualifier]/@Namespace">
          <xsl:value-of select="//edmx:Include[@Alias=$qualifier]/@Namespace" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="//edmx:Include[@Namespace=$qualifier]/@Namespace" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:text>"$ref":"</xsl:text>
    <xsl:call-template name="json-url">
      <xsl:with-param name="url" select="//edmx:Include[@Namespace=$externalNamespace]/../@Uri" />
    </xsl:call-template>
    <xsl:value-of select="$reuse-schemas" />
    <xsl:choose>
      <xsl:when test="$internalNamespace">
        <xsl:value-of select="$internalNamespace" />
      </xsl:when>
      <xsl:when test="string-length($externalNamespace)>0">
        <xsl:value-of select="$externalNamespace" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$qualifier" />
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>.</xsl:text>
    <xsl:value-of select="$name" />
    <xsl:text>"</xsl:text>
  </xsl:template>

  <xsl:template name="schema-ref">
    <xsl:param name="qualifiedName" />
    <xsl:call-template name="ref">
      <xsl:with-param name="qualifier">
        <xsl:call-template name="substring-before-last">
          <xsl:with-param name="input" select="$qualifiedName" />
          <xsl:with-param name="marker" select="'.'" />
        </xsl:call-template>
      </xsl:with-param>
      <xsl:with-param name="name">
        <xsl:call-template name="substring-after-last">
          <xsl:with-param name="input" select="$qualifiedName" />
          <xsl:with-param name="marker" select="'.'" />
        </xsl:call-template>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="repeat">
    <xsl:param name="string" />
    <xsl:param name="count" />
    <xsl:value-of select="$string" />
    <xsl:if test="$count > 1">
      <xsl:call-template name="repeat">
        <xsl:with-param name="string" select="$string" />
        <xsl:with-param name="count" select="$count - 1" />
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template name="nullableType">
    <xsl:param name="type" />
    <xsl:param name="nullable" />
    <xsl:param name="noArray" />
    <xsl:choose>
      <xsl:when test="$openapi-version='2.0'">
        <xsl:text>"type":</xsl:text>
        <xsl:if test="not($noArray) and (not($nullable='false') or contains($type,','))">
          <xsl:text>[</xsl:text>
        </xsl:if>
        <xsl:text>"</xsl:text>
        <xsl:choose>
          <xsl:when test="$noArray and contains($type,',')">
            <xsl:value-of select="substring-before($type,',')" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="replace-all">
              <xsl:with-param name="string" select="$type" />
              <xsl:with-param name="old" select="','" />
              <xsl:with-param name="new" select="'&quot;,&quot;'" />
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text>"</xsl:text>
        <xsl:if test="not($noArray) and not($nullable='false')">
          <xsl:text>,"null"</xsl:text>
        </xsl:if>
        <xsl:if test="not($noArray) and (not($nullable='false') or contains($type,','))">
          <xsl:text>]</xsl:text>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="contains($type,',')">
            <xsl:text>"oneOf":[{"type":"</xsl:text>
            <xsl:call-template name="replace-all">
              <xsl:with-param name="string" select="$type" />
              <xsl:with-param name="old" select="','" />
              <xsl:with-param name="new" select="'&quot;},{&quot;type&quot;:&quot;'" />
            </xsl:call-template>
            <xsl:text>"}]</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>"type":"</xsl:text>
            <xsl:value-of select="$type" />
            <xsl:text>"</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="not($nullable='false')">
          <xsl:text>,"nullable":true</xsl:text>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="@MaxLength">
    <xsl:if test=".!='max'">
      <xsl:text>,"maxLength":</xsl:text>
      <xsl:value-of select="." />
    </xsl:if>
  </xsl:template>

  <xsl:template match="@DefaultValue">
    <xsl:param name="type" />
    <xsl:text>,"default":</xsl:text>
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="$type" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="typeName">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="$type" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="underlyingType">
      <xsl:choose>
        <xsl:when test="//edm:Schema[@Namespace=$qualifier]/edm:TypeDefinition[@Name=$typeName]/@UnderlyingType">
          <xsl:value-of select="//edm:Schema[@Namespace=$qualifier]/edm:TypeDefinition[@Name=$typeName]/@UnderlyingType" />
        </xsl:when>
        <xsl:when test="//edm:Schema[@Alias=$qualifier]/edm:TypeDefinition[@Name=$typeName]/@UnderlyingType">
          <xsl:value-of select="//edm:Schema[@Alias=$qualifier]/edm:TypeDefinition[@Name=$typeName]/@UnderlyingType" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$type" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="underlyingQualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="$underlyingType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test=".='-INF' or .='INF' or .='NaN'">
        <xsl:text>"</xsl:text>
        <xsl:value-of select="." />
        <xsl:text>"</xsl:text>
      </xsl:when>
      <xsl:when
        test="$underlyingType='Edm.Boolean' or $underlyingType='Edm.Decimal' or $underlyingType='Edm.Double' or $underlyingType='Edm.Single'
              or $underlyingType='Edm.Byte' or $underlyingType='Edm.SByte' or $underlyingType='Edm.Int16' or $underlyingType='Edm.Int32' or $underlyingType='Edm.Int64'"
      >
        <xsl:value-of select="." />
      </xsl:when>
      <!-- FAKE: couldn't determine underlying primitive type, so guess from value -->
      <xsl:when test="$underlyingQualifier!='Edm' and (.='true' or .='false' or .='null' or number(.))">
        <xsl:value-of select="." />
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>"</xsl:text>
        <xsl:call-template name="escape">
          <xsl:with-param name="string" select="." />
        </xsl:call-template>
        <xsl:text>"</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="edm:EntityContainer" mode="paths">
    <xsl:apply-templates select="edm:EntitySet|edm:Singleton|edm:FunctionImport|edm:ActionImport" mode="list" />
  </xsl:template>

  <xsl:template match="edm:EntitySet|edm:Singleton" mode="tags">
    <xsl:if test="position() = 1">
      <xsl:text>,"tags":[</xsl:text>
    </xsl:if>
    <xsl:if test="position()>1">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:text>{"name":"</xsl:text>
    <xsl:value-of select="@Name" />

    <xsl:variable name="description">
      <xsl:call-template name="Core.Description">
        <xsl:with-param name="node" select="." />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="$description!=''">
      <xsl:text>","description":"</xsl:text>
      <xsl:value-of select="$description" />
    </xsl:if>

    <xsl:text>"}</xsl:text>
    <xsl:if test="position() = last()">
      <xsl:text>]</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="edm:EntitySet">
    <xsl:apply-templates select="." mode="entitySet" />
    <xsl:apply-templates select="." mode="entity" />
  </xsl:template>

  <xsl:template match="edm:EntitySet" mode="entitySet">
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="@EntityType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="namespace">
      <xsl:choose>
        <xsl:when test="//edm:Schema[@Alias=$qualifier]">
          <xsl:value-of select="//edm:Schema[@Alias=$qualifier]/@Namespace" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$qualifier" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="type">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="@EntityType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="qualifiedType">
      <xsl:value-of select="$namespace" />
      <xsl:text>.</xsl:text>
      <xsl:value-of select="$type" />
    </xsl:variable>

    <xsl:text>"/</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>":{</xsl:text>

    <!-- GET -->
    <xsl:variable name="addressable" select="edm:Annotation[@Term='TODO.Addressable']/@Bool" />
    <xsl:variable name="resultContext"
      select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:Annotation[@Term=concat($commonNamespace,'.ResultContext') or @Term=concat($commonAlias,'.ResultContext')]" />
    <xsl:if test="not($addressable='false') and not($resultContext)">
      <xsl:text>"get":{</xsl:text>
      <xsl:text>"summary":"Get entities from </xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>","tags":["</xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>"]</xsl:text>

      <xsl:text>,"parameters":[</xsl:text>

      <xsl:variable name="top-supported">
        <xsl:call-template name="capability">
          <xsl:with-param name="term" select="'TopSupported'" />
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="not($top-supported='false')">
        <xsl:text>{"$ref":"</xsl:text>
        <xsl:value-of select="$reuse-parameters" />
        <xsl:text>top"},</xsl:text>
      </xsl:if>

      <xsl:variable name="skip-supported">
        <xsl:call-template name="capability">
          <xsl:with-param name="term" select="'SkipSupported'" />
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="not($skip-supported='false')">
        <xsl:text>{"$ref":"</xsl:text>
        <xsl:value-of select="$reuse-parameters" />
        <xsl:text>skip"},</xsl:text>
      </xsl:if>

      <xsl:if test="$odata-version='4.0'">
        <xsl:text>{"$ref":"</xsl:text>
        <xsl:value-of select="$reuse-parameters" />
        <xsl:text>search"},</xsl:text>
      </xsl:if>

      <xsl:variable name="filter-required">
        <xsl:call-template name="capability">
          <xsl:with-param name="term" select="'FilterRestrictions'" />
          <xsl:with-param name="property" select="'RequiresFilter'" />
        </xsl:call-template>
      </xsl:variable>
      <xsl:text>{"name":"$filter","in":"query","description":"Filter items by property values</xsl:text>
      <xsl:text>, see [OData Filtering](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374625)</xsl:text>
      <xsl:apply-templates
        select="edm:Annotation[@Term=concat($capabilitiesNamespace,'.FilterRestrictions') or @Term=concat($capabilitiesAlias,'.FilterRestrictions')]/edm:Record/edm:PropertyValue[@Property='RequiredProperties']/edm:Collection/edm:PropertyPath"
        mode="filter-RequiredProperties" />
      <xsl:text>",</xsl:text>
      <xsl:call-template name="parameter-type">
        <xsl:with-param name="type" select="'string'" />
      </xsl:call-template>
      <xsl:if test="$filter-required='true'">
        <xsl:text>,"required":true</xsl:text>
      </xsl:if>
      <xsl:text>},</xsl:text>

      <xsl:text>{"$ref":"</xsl:text>
      <xsl:value-of select="$reuse-parameters" />
      <xsl:text>count"}</xsl:text>

      <xsl:variable name="non-sortable"
        select="edm:Annotation[@Term=concat($capabilitiesNamespace,'.SortRestrictions') or @Term=concat($capabilitiesAlias,'.SortRestrictions')]/edm:Record/edm:PropertyValue[@Property='NonSortableProperties']/edm:Collection/edm:PropertyPath" />
      <xsl:apply-templates
        select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:Property[not(@Name=$non-sortable)]" mode="orderby" />

      <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:Property"
        mode="select" />
      <xsl:apply-templates
        select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:NavigationProperty|//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:Property[@Type='Edm.Stream']"
        mode="expand" />

      <xsl:text>]</xsl:text>

      <xsl:call-template name="responses">
        <xsl:with-param name="code" select="'200'" />
        <xsl:with-param name="type" select="concat('Collection(',$qualifiedType,')')" />
        <xsl:with-param name="description" select="'Retrieved entities'" />
        <xsl:with-param name="innerDescription" select="concat('Collection of ',$type)" />
      </xsl:call-template>

      <xsl:text>}</xsl:text>
    </xsl:if>

    <!-- POST -->
    <xsl:variable name="insertable">
      <xsl:call-template name="capability">
        <xsl:with-param name="term" select="'InsertRestrictions'" />
        <xsl:with-param name="property" select="'Insertable'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="not($addressable='false') and not($resultContext) and not($insertable='false')">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:if test="not($insertable='false')">
      <xsl:text>"post":{</xsl:text>
      <xsl:text>"summary":"Add new entity to </xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>","tags":["</xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>"],</xsl:text>

      <xsl:choose>
        <xsl:when test="$openapi-version='2.0'">
          <xsl:text>"parameters":[{"name":"</xsl:text>
          <xsl:value-of select="$type" />
          <xsl:text>","in":"body",</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>"requestBody":{"required":true,</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="entityTypeDescription">
        <xsl:with-param name="namespace" select="$namespace" />
        <xsl:with-param name="type" select="$type" />
        <xsl:with-param name="default" select="'New entity'" />
      </xsl:call-template>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>"content":{"application/json":{</xsl:text>
      </xsl:if>
      <xsl:text>"schema":{</xsl:text>
      <xsl:call-template name="schema-ref">
        <xsl:with-param name="qualifiedName" select="$qualifiedType" />
      </xsl:call-template>
      <xsl:text>}</xsl:text>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>}}</xsl:text>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="$openapi-version='2.0'">
          <xsl:text>}]</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>}</xsl:text>
        </xsl:otherwise>
      </xsl:choose>

      <xsl:call-template name="responses">
        <xsl:with-param name="code" select="'201'" />
        <xsl:with-param name="type" select="$qualifiedType" />
        <xsl:with-param name="description" select="'Created entity'" />
        <xsl:with-param name="innerDescription" select="concat('Created ',$type)" />
      </xsl:call-template>
      <xsl:text>}</xsl:text>
    </xsl:if>

    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template name="capability">
    <xsl:param name="term" />
    <xsl:param name="property" select="false()" />
    <xsl:param name="target" select="." />
    <xsl:choose>
      <xsl:when test="$property">
        <xsl:value-of
          select="$target/edm:Annotation[@Term=concat($capabilitiesNamespace,'.',$term) or @Term=concat($capabilitiesAlias,'.',$term)]/edm:Record/edm:PropertyValue[@Property=$property]/@Bool
                 |$target/edm:Annotation[@Term=concat($capabilitiesNamespace,'.',$term) or @Term=concat($capabilitiesAlias,'.',$term)]/edm:Record/edm:PropertyValue[@Property=$property]/edm:Bool" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of
          select="$target/edm:Annotation[@Term=concat($capabilitiesNamespace,'.',$term) or @Term=concat($capabilitiesAlias,'.',$term)]/@Bool
                 |$target/edm:Annotation[@Term=concat($capabilitiesNamespace,'.',$term) or @Term=concat($capabilitiesAlias,'.',$term)]/edm:Bool" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="edm:Property" mode="orderby">
    <xsl:param name="after" select="'something'" />
    <xsl:if test="position()=1">
      <xsl:if test="$after">
        <xsl:text>,</xsl:text>
      </xsl:if>
      <xsl:text>{"name":"$orderby","in":"query","description":"Order items by property values</xsl:text>
      <xsl:text>, see [OData Sorting](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374629)",</xsl:text>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>"schema":{</xsl:text>
      </xsl:if>
      <xsl:text>"type":"array","uniqueItems":true,"items":{"type":"string","enum":[</xsl:text>
    </xsl:if>
    <xsl:if test="position()>1">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:text>"</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>","</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text> desc"</xsl:text>
    <xsl:if test="position()=last()">
      <xsl:text>]}}</xsl:text>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>}</xsl:text>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <xsl:template match="edm:Property" mode="select">
    <xsl:param name="after" select="'something'" />
    <xsl:if test="position()=1">
      <xsl:if test="$after">
        <xsl:text>,</xsl:text>
      </xsl:if>
      <xsl:text>{"name":"$select","in":"query","description":"Select properties to be returned</xsl:text>
      <xsl:text>, see [OData Select](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374620)",</xsl:text>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>"schema":{</xsl:text>
      </xsl:if>
      <xsl:text>"type":"array","uniqueItems":true,"items":{"type":"string","enum":[</xsl:text>
    </xsl:if>
    <xsl:if test="position()>1">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:text>"</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>"</xsl:text>
    <xsl:if test="position()=last()">
      <xsl:text>]}}</xsl:text>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>}</xsl:text>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <xsl:template match="edm:Property|edm:NavigationProperty" mode="expand">
    <xsl:param name="after" select="'something'" />
    <xsl:if test="position()=1">
      <xsl:if test="$after">
        <xsl:text>,</xsl:text>
      </xsl:if>
      <xsl:text>{"name":"$expand","in":"query","description":"Expand related entities</xsl:text>
      <xsl:text>, see [OData Expand](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374621)",</xsl:text>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>"schema":{</xsl:text>
      </xsl:if>
      <xsl:text>"type":"array","uniqueItems":true,"items":{"type":"string","enum":["*"</xsl:text>
    </xsl:if>
    <xsl:if test="local-name()='NavigationProperty' or /edmx:Edmx/@Version='4.01'">
      <xsl:text>,"</xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>"</xsl:text>
    </xsl:if>
    <xsl:if test="position()=last()">
      <xsl:text>]}}</xsl:text>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>}</xsl:text>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <xsl:template match="edm:EntitySet" mode="entity">
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="@EntityType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="namespace">
      <xsl:choose>
        <xsl:when test="//edm:Schema[@Alias=$qualifier]">
          <xsl:value-of select="//edm:Schema[@Alias=$qualifier]/@Namespace" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$qualifier" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="type">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="@EntityType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="qualifiedType">
      <xsl:value-of select="$namespace" />
      <xsl:text>.</xsl:text>
      <xsl:value-of select="$type" />
    </xsl:variable>
    <xsl:variable name="aliasQualifiedType">
      <xsl:value-of select="//edm:Schema[@Namespace=$namespace]/@Alias" />
      <xsl:text>.</xsl:text>
      <xsl:value-of select="$type" />
    </xsl:variable>

    <!-- entity path template -->
    <xsl:text>,"/</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" mode="key-in-path" />
    <xsl:text>":{</xsl:text>

    <!-- GET -->
    <xsl:variable name="addressable" select="edm:Annotation[@Term='TODO.Addressable']/@Bool" />
    <xsl:variable name="resultContext"
      select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:Annotation[@Term=concat($commonNamespace,'.ResultContext') or @Term=concat($commonAlias,'.ResultContext')]" />
    <xsl:if test="not($addressable='false') and not($resultContext)">
      <xsl:text>"get":{</xsl:text>
      <xsl:text>"summary":"Get entity from </xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text> by key","tags":["</xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>"]</xsl:text>
      <xsl:text>,"parameters":[</xsl:text>
      <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" mode="parameter" />
      <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:Property"
        mode="select" />
      <xsl:apply-templates
        select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:NavigationProperty|//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:Property[@Type='Edm.Stream']"
        mode="expand" />
      <xsl:text>]</xsl:text>

      <xsl:call-template name="responses">
        <xsl:with-param name="type" select="$qualifiedType" />
        <xsl:with-param name="description" select="'Retrieved entity'" />
        <xsl:with-param name="innerDescription" select="$type" />
      </xsl:call-template>
      <xsl:text>}</xsl:text>
    </xsl:if>

    <!-- PATCH -->
    <xsl:variable name="updatable">
      <xsl:call-template name="capability">
        <xsl:with-param name="term" select="'UpdateRestrictions'" />
        <xsl:with-param name="property" select="'Updatable'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="not($addressable='false') and not($resultContext) and not($updatable='false')">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:if test="not($updatable='false')">
      <xsl:text>"patch":{</xsl:text>
      <xsl:text>"summary":"Update entity in </xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>","tags":["</xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>"],</xsl:text>

      <xsl:text>"parameters":[</xsl:text>
      <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" mode="parameter" />

      <xsl:choose>
        <xsl:when test="$openapi-version='2.0'">
          <xsl:text>,{"name":"</xsl:text>
          <xsl:value-of select="$type" />
          <xsl:text>","in":"body",</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>],"requestBody":{"required":true,</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="entityTypeDescription">
        <xsl:with-param name="namespace" select="$namespace" />
        <xsl:with-param name="type" select="$type" />
        <xsl:with-param name="default" select="'New property values'" />
      </xsl:call-template>
      <xsl:if test="$openapi-version!='2.0'">
        <xsl:text>"content":{"application/json":{</xsl:text>
      </xsl:if>
      <xsl:text>"schema":{</xsl:text>
      <xsl:if test="$odata-version='2.0'">
        <xsl:text>"title":"Modified </xsl:text>
        <xsl:value-of select="$type" />
        <xsl:text>","type":"object","properties":{"d":{</xsl:text>
      </xsl:if>
      <xsl:call-template name="schema-ref">
        <xsl:with-param name="qualifiedName" select="$qualifiedType" />
      </xsl:call-template>
      <xsl:if test="$odata-version='2.0'">
        <xsl:text>}}</xsl:text>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="$openapi-version='2.0'">
          <xsl:text>}}]</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>}}}}</xsl:text>
        </xsl:otherwise>
      </xsl:choose>

      <xsl:call-template name="responses" />

      <xsl:text>}</xsl:text>
    </xsl:if>

    <!-- DELETE -->
    <xsl:variable name="deletable">
      <xsl:call-template name="capability">
        <xsl:with-param name="term" select="'DeleteRestrictions'" />
        <xsl:with-param name="property" select="'Deletable'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="(not($addressable='false') or not($updatable='false')) and not($deletable='false')">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:if test="not($deletable='false')">
      <xsl:text>"delete":{</xsl:text>
      <xsl:text>"summary":"Delete entity from </xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>","tags":["</xsl:text>
      <xsl:value-of select="@Name" />
      <xsl:text>"]</xsl:text>
      <xsl:text>,"parameters":[</xsl:text>
      <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" mode="parameter" />
      <xsl:call-template name="if-match" />
      <xsl:text>]</xsl:text>
      <xsl:call-template name="responses" />
      <xsl:text>}</xsl:text>
    </xsl:if>

    <xsl:text>}</xsl:text>

    <xsl:apply-templates
      select="//edm:Function[@IsBound='true' and (edm:Parameter[1]/@Type=$qualifiedType or edm:Parameter[1]/@Type=$aliasQualifiedType)]"
      mode="bound"
    >
      <xsl:with-param name="entitySet" select="@Name" />
      <xsl:with-param name="namespace" select="$namespace" />
      <xsl:with-param name="type" select="$type" />
    </xsl:apply-templates>
    <xsl:apply-templates
      select="//edm:Action[@IsBound='true' and (edm:Parameter[1]/@Type=$qualifiedType or edm:Parameter[1]/@Type=$aliasQualifiedType)]"
      mode="bound"
    >
      <xsl:with-param name="entitySet" select="@Name" />
      <xsl:with-param name="namespace" select="$namespace" />
      <xsl:with-param name="type" select="$type" />
    </xsl:apply-templates>

    <xsl:if test="$resultContext">
      <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:NavigationProperty"
        mode="resultContext"
      >
        <xsl:with-param name="entitySet" select="@Name" />
        <xsl:with-param name="namespace" select="$namespace" />
        <xsl:with-param name="type" select="$type" />
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>

  <xsl:template name="if-match">
    <xsl:text>,{"name":"If-Match","in":"header","description":"ETag",</xsl:text>
    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>"schema":{</xsl:text>
    </xsl:if>
    <xsl:text>"type":"string"</xsl:text>
    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>}</xsl:text>
    </xsl:if>
    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:Singleton">
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="@Type" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="namespace">
      <xsl:choose>
        <xsl:when test="//edm:Schema[@Alias=$qualifier]">
          <xsl:value-of select="//edm:Schema[@Alias=$qualifier]/@Namespace" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$qualifier" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="type">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="@Type" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="qualifiedType">
      <xsl:value-of select="$namespace" />
      <xsl:text>.</xsl:text>
      <xsl:value-of select="$type" />
    </xsl:variable>
    <xsl:variable name="aliasQualifiedType">
      <xsl:value-of select="//edm:Schema[@Namespace=$namespace]/@Alias" />
      <xsl:text>.</xsl:text>
      <xsl:value-of select="$type" />
    </xsl:variable>

    <!-- singleton path template -->
    <xsl:text>"/</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>":{</xsl:text>

    <!-- GET -->
    <xsl:text>"get":{</xsl:text>
    <xsl:text>"summary":"Get </xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>","tags":["</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>"]</xsl:text>
    <xsl:text>,"parameters":[</xsl:text>

    <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:Property"
      mode="select"
    >
      <xsl:with-param name="after" select="''" />
    </xsl:apply-templates>
    <xsl:apply-templates
      select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:NavigationProperty|//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]/edm:Property[@Type='Edm.Stream']"
      mode="expand" />
    <xsl:text>]</xsl:text>

    <xsl:call-template name="responses">
      <xsl:with-param name="type" select="$qualifiedType" />
      <xsl:with-param name="description" select="'Retrieved entity'" />
      <xsl:with-param name="innerDescription" select="$type" />
    </xsl:call-template>
    <xsl:text>}</xsl:text>


    <!-- PATCH -->
    <xsl:text>,"patch":{</xsl:text>
    <xsl:text>"summary":"Update </xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>","tags":["</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>"],</xsl:text>

    <xsl:choose>
      <xsl:when test="$openapi-version='2.0'">
        <xsl:text>"parameters":[{"name":"</xsl:text>
        <xsl:value-of select="$type" />
        <xsl:text>","in":"body",</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>"requestBody":{"required":true,</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="entityTypeDescription">
      <xsl:with-param name="namespace" select="$namespace" />
      <xsl:with-param name="type" select="$type" />
      <xsl:with-param name="default" select="'New property values'" />
    </xsl:call-template>
    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>"content":{"application/json":{</xsl:text>
    </xsl:if>
    <xsl:text>"schema":{</xsl:text>
    <xsl:call-template name="schema-ref">
      <xsl:with-param name="qualifiedName" select="$qualifiedType" />
    </xsl:call-template>
    <xsl:text>}</xsl:text>
    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>}}</xsl:text>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="$openapi-version='2.0'">
        <xsl:text>}]</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>}</xsl:text>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:call-template name="responses" />

    <xsl:text>}}</xsl:text>

    <xsl:apply-templates
      select="//edm:Function[@IsBound='true' and (edm:Parameter[1]/@Type=$qualifiedType or edm:Parameter[1]/@Type=$aliasQualifiedType)]"
      mode="bound"
    >
      <xsl:with-param name="singleton" select="@Name" />
      <xsl:with-param name="namespace" select="$namespace" />
      <xsl:with-param name="type" select="$type" />
    </xsl:apply-templates>
    <xsl:apply-templates
      select="//edm:Action[@IsBound='true' and (edm:Parameter[1]/@Type=$qualifiedType or edm:Parameter[1]/@Type=$aliasQualifiedType)]"
      mode="bound"
    >
      <xsl:with-param name="singleton" select="@Name" />
      <xsl:with-param name="namespace" select="$namespace" />
      <xsl:with-param name="type" select="$type" />
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template name="entityTypeDescription">
    <xsl:param name="namespace" />
    <xsl:param name="type" />
    <xsl:param name="default" />
    <xsl:text>"description":"</xsl:text>
    <xsl:variable name="description">
      <xsl:call-template name="Core.Description">
        <xsl:with-param name="node" select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$description!=''">
        <xsl:value-of select="$description" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$default" />
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>",</xsl:text>
  </xsl:template>

  <xsl:template match="edm:EntityType" mode="key-in-path">
    <xsl:choose>
      <xsl:when test="edm:Key">
        <xsl:choose>
          <xsl:when test="$key-as-segment">
            <xsl:text>/</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>(</xsl:text>
          </xsl:otherwise>
        </xsl:choose>

        <xsl:apply-templates select="edm:Key/edm:PropertyRef" mode="key-in-path" />

        <xsl:if test="not($key-as-segment)">
          <xsl:text>)</xsl:text>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="basetypeQualifier">
          <xsl:call-template name="substring-before-last">
            <xsl:with-param name="input" select="@BaseType" />
            <xsl:with-param name="marker" select="'.'" />
          </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="basetypeNamespace">
          <xsl:choose>
            <xsl:when test="//edm:Schema[@Alias=$basetypeQualifier]">
              <xsl:value-of select="//edm:Schema[@Alias=$basetypeQualifier]/@Namespace" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$basetypeQualifier" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="basetype">
          <xsl:call-template name="substring-after-last">
            <xsl:with-param name="input" select="@BaseType" />
            <xsl:with-param name="marker" select="'.'" />
          </xsl:call-template>
        </xsl:variable>

        <xsl:apply-templates select="//edm:Schema[@Namespace=$basetypeNamespace]/edm:EntityType[@Name=$basetype]"
          mode="key-in-path" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="edm:PropertyRef" mode="key-in-path">
    <xsl:variable name="name" select="@Name" />
    <xsl:variable name="type" select="../../edm:Property[@Name=$name]/@Type" />
    <xsl:if test="position()>1">
      <xsl:choose>
        <xsl:when test="$key-as-segment">
          <xsl:text>/</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>,</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
    <xsl:if test="last()>1 and not($key-as-segment)">
      <xsl:value-of select="@Name" />
      <xsl:text>=</xsl:text>
    </xsl:if>
    <xsl:call-template name="pathValuePrefix">
      <xsl:with-param name="type" select="$type" />
    </xsl:call-template>
    <xsl:text>{</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>}</xsl:text>
    <xsl:call-template name="pathValueSuffix">
      <xsl:with-param name="type" select="$type" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="pathValuePrefix">
    <xsl:param name="type" />
    <xsl:choose>
      <xsl:when
        test="$type='Edm.Int64' or $type='Edm.Int32' or $type='Edm.Int16' or $type='Edm.SByte' or $type='Edm.Byte' or $type='Edm.Double' or $type='Edm.Single' or $type='Edm.Date' or $type='Edm.DateTimeOffset' or $type='Edm.Guid'" />
      <!-- TODO: handle other Edm types, enumeration types, and type definitions -->
      <xsl:otherwise>
        <xsl:if test="not($key-as-segment)">
          <xsl:text>'</xsl:text>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="pathValueSuffix">
    <xsl:param name="type" />
    <xsl:choose>
      <xsl:when
        test="$type='Edm.Int64' or $type='Edm.Int32' or $type='Edm.Int16' or $type='Edm.SByte' or $type='Edm.Byte' or $type='Edm.Double' or $type='Edm.Single' or $type='Edm.Date' or $type='Edm.DateTimeOffset' or $type='Edm.Guid'" />
      <!-- TODO: handle other Edm types, enumeration types, and type definitions -->
      <xsl:otherwise>
        <xsl:if test="not($key-as-segment)">
          <xsl:text>'</xsl:text>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="edm:EntityType" mode="parameter">
    <xsl:choose>
      <xsl:when test="edm:Key">
        <xsl:apply-templates select="edm:Key/edm:PropertyRef" mode="parameter" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="basetypeQualifier">
          <xsl:call-template name="substring-before-last">
            <xsl:with-param name="input" select="@BaseType" />
            <xsl:with-param name="marker" select="'.'" />
          </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="basetypeNamespace">
          <xsl:choose>
            <xsl:when test="//edm:Schema[@Alias=$basetypeQualifier]">
              <xsl:value-of select="//edm:Schema[@Alias=$basetypeQualifier]/@Namespace" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$basetypeQualifier" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="basetype">
          <xsl:call-template name="substring-after-last">
            <xsl:with-param name="input" select="@BaseType" />
            <xsl:with-param name="marker" select="'.'" />
          </xsl:call-template>
        </xsl:variable>

        <xsl:apply-templates select="//edm:Schema[@Namespace=$basetypeNamespace]/edm:EntityType[@Name=$basetype]"
          mode="parameter" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="edm:PropertyRef" mode="parameter">
    <xsl:variable name="name" select="@Name" />
    <xsl:variable name="type" select="../../edm:Property[@Name=$name]/@Type" />
    <xsl:if test="position()>1">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:text>{"name":"</xsl:text>
    <xsl:value-of select="$name" />
    <xsl:text>","in":"path","required":true,"description":"</xsl:text>
    <xsl:variable name="description">
      <xsl:call-template name="description">
        <xsl:with-param name="node" select="../../edm:Property[@Name=$name]" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$description!=''">
        <xsl:value-of select="$description" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>key: </xsl:text>
        <xsl:value-of select="$name" />
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>",</xsl:text>

    <xsl:choose>
      <xsl:when test="$openapi-version='2.0'">
        <xsl:text>"type":</xsl:text>
        <xsl:choose>
          <xsl:when test="$type='Edm.Int64'">
            <xsl:text>"integer","format":"int64"</xsl:text>
          </xsl:when>
          <xsl:when test="$type='Edm.Int32'">
            <xsl:text>"integer","format":"int32"</xsl:text>
          </xsl:when>
          <!-- TODO: handle other Edm types, enumeration types, and type definitions -->
          <xsl:otherwise>
            <xsl:text>"string"</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>"schema":{</xsl:text>
        <xsl:call-template name="type">
          <xsl:with-param name="type" select="$type" />
          <xsl:with-param name="nullableFacet" select="'false'" />
        </xsl:call-template>
        <xsl:text>}</xsl:text>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:ActionImport">
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="@Action" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="namespace">
      <xsl:choose>
        <xsl:when test="//edm:Schema[@Alias=$qualifier]">
          <xsl:value-of select="//edm:Schema[@Alias=$qualifier]/@Namespace" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$qualifier" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="action">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="@Action" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>

    <xsl:text>"/</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>":{"post":{"summary":"</xsl:text>
    <xsl:variable name="summary"
      select="edm:Annotation[@Term=$commonLabel or @Term=$commonLabelAliased]/@String|//edm:Schema/edm:Annotation[@Term=$commonLabel or @Term=$commonLabelAliased]/edm:String" />
    <xsl:choose>
      <xsl:when test="$summary">
        <xsl:call-template name="escape">
          <xsl:with-param name="string" select="$summary" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>Invoke action </xsl:text>
        <xsl:value-of select="@Name" />
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>","tags":["</xsl:text>
    <xsl:choose>
      <xsl:when test="@EntitySet">
        <xsl:value-of select="@EntitySet" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>Service Operations</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>"]</xsl:text>
    <xsl:variable name="parameters"
      select="//edm:Schema[@Namespace=$namespace]/edm:Action[@Name=$action and not(@IsBound='true')]/edm:Parameter" />
    <xsl:if test="$parameters">
      <xsl:choose>
        <xsl:when test="$odata-version='2.0'">
          <xsl:text>,"parameters":[</xsl:text>
          <xsl:apply-templates select="$parameters" mode="parameter" />
          <xsl:text>]</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="$openapi-version='2.0'">
              <xsl:text>,"parameters":[{"name":"body","in":"body",</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>,"requestBody":{</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:text>"description":"Action parameters",</xsl:text>
          <xsl:if test="$openapi-version!='2.0'">
            <xsl:text>"content":{"application/json":{</xsl:text>
          </xsl:if>
          <xsl:text>"schema":{"type":"object"</xsl:text>
          <xsl:apply-templates select="$parameters" mode="hash">
            <xsl:with-param name="name" select="'properties'" />
          </xsl:apply-templates>
          <xsl:choose>
            <xsl:when test="$openapi-version='2.0'">
              <xsl:text>}}]</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>}}}}</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>

    <xsl:call-template name="responses">
      <xsl:with-param name="type" select="//edm:Schema[@Namespace=$namespace]/edm:Action[@Name=$action]/edm:ReturnType/@Type" />
    </xsl:call-template>
    <xsl:text>}}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:FunctionImport">
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="@Function" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="namespace">
      <xsl:choose>
        <xsl:when test="//edm:Schema[@Alias=$qualifier]">
          <xsl:value-of select="//edm:Schema[@Alias=$qualifier]/@Namespace" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$qualifier" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="function">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="@Function" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>

    <!-- need to apply templates for all function overloads that match the function name -->
    <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:Function[@Name=$function]" mode="import">
      <xsl:with-param name="functionImport" select="@Name" />
      <xsl:with-param name="entitySet" select="@EntitySet" />
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="edm:Function" mode="import">
    <xsl:param name="functionImport" />
    <xsl:param name="entitySet" />

    <xsl:text>"/</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:if test="$odata-version!='2.0'">
      <xsl:text>(</xsl:text>
      <xsl:apply-templates select="edm:Parameter" mode="path" />
      <xsl:text>)</xsl:text>
    </xsl:if>
    <xsl:text>":{"get":{"summary":"</xsl:text>
    <xsl:variable name="summary"
      select="edm:Annotation[@Term=$commonLabel or @Term=$commonLabelAliased]/@String|//edm:Schema/edm:Annotation[@Term=$commonLabel or @Term=$commonLabelAliased]/edm:String" />
    <xsl:choose>
      <xsl:when test="$summary">
        <xsl:call-template name="escape">
          <xsl:with-param name="string" select="$summary" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>Invoke function </xsl:text>
        <xsl:value-of select="@Name" />
      </xsl:otherwise>
    </xsl:choose>

    <xsl:text>","tags":["</xsl:text>
    <xsl:choose>
      <xsl:when test="$entitySet">
        <xsl:value-of select="$entitySet" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>Service Operations</xsl:text>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:text>"],"parameters":[</xsl:text>
    <xsl:apply-templates select="edm:Parameter" mode="parameter" />
    <xsl:text>]</xsl:text>

    <xsl:call-template name="responses">
      <xsl:with-param name="type" select="edm:ReturnType/@Type" />
    </xsl:call-template>
    <xsl:text>}}</xsl:text>
  </xsl:template>

  <xsl:template name="responses">
    <xsl:param name="code" select="'200'" />
    <xsl:param name="type" select="null" />
    <xsl:param name="description" select="'Success'" />
    <xsl:param name="innerDescription" select="'Result'" />

    <xsl:variable name="collection" select="starts-with($type,'Collection(')" />

    <xsl:text>,"responses":{</xsl:text>
    <xsl:choose>
      <xsl:when test="not($type)">
        <xsl:text>"204":{"description":"</xsl:text>
        <xsl:value-of select="$description" />
        <xsl:text>"}</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>"</xsl:text>
        <xsl:value-of select="$code" />
        <xsl:text>":{"description":"</xsl:text>
        <xsl:value-of select="$description" />
        <xsl:text>",</xsl:text>
        <xsl:if test="$openapi-version!='2.0'">
          <xsl:text>"content":{"application/json":{</xsl:text>
        </xsl:if>
        <xsl:text>"schema":{</xsl:text>
        <xsl:if test="$collection or $odata-version='2.0'">
          <xsl:text>"title":"</xsl:text>
          <xsl:choose>
            <xsl:when test="$collection and $odata-version='2.0'">
              <xsl:text>Wrapper</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$innerDescription" />
            </xsl:otherwise>
          </xsl:choose>
          <xsl:text>","type":"object","properties":{"</xsl:text>
          <xsl:choose>
            <xsl:when test="$odata-version='2.0'">
              <xsl:text>d</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>value</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:text>":{</xsl:text>
        </xsl:if>
        <xsl:call-template name="type">
          <xsl:with-param name="type" select="$type" />
          <xsl:with-param name="nullableFacet" select="'false'" />
        </xsl:call-template>
        <xsl:if test="$collection or $odata-version='2.0'">
          <xsl:text>}}</xsl:text>
        </xsl:if>
        <xsl:if test="$openapi-version!='2.0'">
          <xsl:text>}}</xsl:text>
        </xsl:if>
        <xsl:text>}}</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>,</xsl:text>
    <xsl:value-of select="$defaultResponse" />
    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:NavigationProperty" mode="resultContext">
    <xsl:param name="entitySet" />
    <xsl:param name="namespace" />
    <xsl:param name="type" />

    <xsl:variable name="nullable">
      <xsl:call-template name="nullableFacetValue">
        <xsl:with-param name="type" select="@Type" />
        <xsl:with-param name="nullableFacet" select="@Nullable" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="collection" select="starts-with(@Type,'Collection(')" />
    <xsl:variable name="singleType">
      <xsl:choose>
        <xsl:when test="$collection">
          <xsl:value-of select="substring-before(substring-after(@Type,'('),')')" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@Type" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="qualifier">
      <xsl:call-template name="substring-before-last">
        <xsl:with-param name="input" select="$singleType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="targetNamespace">
      <xsl:choose>
        <xsl:when test="//edm:Schema[@Alias=$qualifier]">
          <xsl:value-of select="//edm:Schema[@Alias=$qualifier]/@Namespace" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$qualifier" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="simpleName">
      <xsl:call-template name="substring-after-last">
        <xsl:with-param name="input" select="$singleType" />
        <xsl:with-param name="marker" select="'.'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="targetType">
      <xsl:value-of select="$targetNamespace" />
      <xsl:text>.</xsl:text>
      <xsl:value-of select="$simpleName" />
    </xsl:variable>

    <xsl:text>,"/</xsl:text>
    <xsl:value-of select="$entitySet" />
    <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" mode="key-in-path" />
    <xsl:text>/</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>":{"get":{</xsl:text>
    <!-- TODO: better summary / description -->
    <xsl:text>"summary":"Get </xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>","tags":["</xsl:text>
    <xsl:value-of select="$entitySet" />
    <xsl:text>"]</xsl:text>

    <xsl:text>,"parameters":[</xsl:text>
    <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" mode="parameter" />

    <xsl:variable name="name" select="@Name" />
    <xsl:variable name="targetEntitySetName" select="//edm:EntitySet[@Name=$entitySet]/edm:NavigationPropertyBinding[@Path=$name]/@Target" />
    <xsl:variable name="targetSet" select="//edm:EntitySet[@Name=$targetEntitySetName]" />

    <xsl:variable name="filter-required">
      <xsl:call-template name="capability">
        <xsl:with-param name="term" select="'FilterRestrictions'" />
        <xsl:with-param name="property" select="'RequiresFilter'" />
        <xsl:with-param name="target" select="$targetSet" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:text>,{"name":"$filter","in":"query","description":"Filter items by property values</xsl:text>
    <xsl:text>, see [OData Filtering](http://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html#_Toc445374625)</xsl:text>
    <xsl:apply-templates
      select="$targetSet/edm:Annotation[@Term=concat($capabilitiesNamespace,'.FilterRestrictions') or @Term=concat($capabilitiesAlias,'.FilterRestrictions')]/edm:Record/edm:PropertyValue[@Property='RequiredProperties']/edm:Collection/edm:PropertyPath"
      mode="filter-RequiredProperties" />
    <xsl:text>",</xsl:text>
    <xsl:call-template name="parameter-type">
      <xsl:with-param name="type" select="'string'" />
    </xsl:call-template>
    <xsl:if test="$filter-required='true'">
      <xsl:text>,"required":true</xsl:text>
    </xsl:if>
    <xsl:text>}</xsl:text>

    <xsl:variable name="top-supported">
      <xsl:call-template name="capability">
        <xsl:with-param name="term" select="'TopSupported'" />
        <xsl:with-param name="target" select="$targetSet" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="not($top-supported='false')">
      <xsl:text>,{"$ref":"</xsl:text>
      <xsl:value-of select="$reuse-parameters" />
      <xsl:text>top"}</xsl:text>
    </xsl:if>

    <xsl:variable name="skip-supported">
      <xsl:call-template name="capability">
        <xsl:with-param name="term" select="'SkipSupported'" />
        <xsl:with-param name="target" select="$targetSet" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="not($skip-supported='false')">
      <xsl:text>,{"$ref":"</xsl:text>
      <xsl:value-of select="$reuse-parameters" />
      <xsl:text>skip"}</xsl:text>
    </xsl:if>

    <xsl:if test="$odata-version='4.0'">
      <xsl:text>,{"$ref":"</xsl:text>
      <xsl:value-of select="$reuse-parameters" />
      <xsl:text>search"}</xsl:text>
    </xsl:if>

    <xsl:text>,{"$ref":"</xsl:text>
    <xsl:value-of select="$reuse-parameters" />
    <xsl:text>count"}</xsl:text>

    <xsl:variable name="non-sortable"
      select="$targetSet/edm:Annotation[@Term=concat($capabilitiesNamespace,'.SortRestrictions') or @Term=concat($capabilitiesAlias,'.SortRestrictions')]/edm:Record/edm:PropertyValue[@Property='NonSortableProperties']/edm:Collection/edm:PropertyPath" />
    <xsl:apply-templates
      select="//edm:Schema[@Namespace=$targetNamespace]/edm:EntityType[@Name=$simpleName]/edm:Property[not(@Name=$non-sortable)]"
      mode="orderby" />

    <xsl:apply-templates select="//edm:Schema[@Namespace=$targetNamespace]/edm:EntityType[@Name=$simpleName]/edm:Property"
      mode="select" />
    <xsl:apply-templates
      select="//edm:Schema[@Namespace=$targetNamespace]/edm:EntityType[@Name=$simpleName]/edm:NavigationProperty|//edm:Schema[@Namespace=$targetNamespace]/edm:EntityType[@Name=$simpleName]/edm:Property[@Type='Edm.Stream']"
      mode="expand" />

    <xsl:text>]</xsl:text>

    <xsl:call-template name="responses">
      <xsl:with-param name="code" select="'200'" />
      <xsl:with-param name="type" select="concat('Collection(',$targetType,')')" />
      <xsl:with-param name="description" select="'Retrieved entities'" />
      <xsl:with-param name="innerDescription" select="concat('Collection of ',$simpleName)" />
    </xsl:call-template>

    <xsl:text>}}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:PropertyPath" mode="filter-RequiredProperties">
    <xsl:if test="position()=1">
      <xsl:text>\n\nRequired filter properties:</xsl:text>
    </xsl:if>
    <xsl:text>\n- </xsl:text>
    <xsl:value-of select="." />
  </xsl:template>

  <xsl:template match="edm:Action" mode="bound">
    <xsl:param name="entitySet" />
    <xsl:param name="singleton" />
    <xsl:param name="namespace" />
    <xsl:param name="type" />

    <xsl:text>,"/</xsl:text>
    <xsl:choose>
      <xsl:when test="$entitySet">
        <xsl:value-of select="$entitySet" />
        <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" mode="key-in-path" />
      </xsl:when>
      <xsl:when test="$singleton">
        <xsl:value-of select="$singleton" />
      </xsl:when>
    </xsl:choose>
    <xsl:text>/</xsl:text>
    <xsl:choose>
      <xsl:when
        test="../edm:Annotation[(@Term='Org.OData.Core.V1.DefaultNamespace' or @Term=concat($coreAlias,'.DefaultNamespace')) and not(@Qualifier)]" />
      <xsl:when test="../@Alias">
        <xsl:value-of select="../@Alias" />
        <xsl:text>.</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="../@Namespace" />
        <xsl:text>.</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="@Name" />
    <xsl:text>":{"post":{</xsl:text>
    <xsl:call-template name="summary-description">
      <xsl:with-param name="fallback-summary">
        <xsl:text>Invoke action </xsl:text>
        <xsl:value-of select="@Name" />
      </xsl:with-param>
    </xsl:call-template>
    <xsl:text>,"tags":["</xsl:text>
    <xsl:value-of select="$entitySet" />
    <xsl:value-of select="$singleton" />
    <xsl:text>"],"parameters":[</xsl:text>
    <xsl:if test="$entitySet">
      <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" mode="parameter" />
    </xsl:if>

    <xsl:choose>
      <xsl:when test="$openapi-version='2.0'">
        <xsl:if test="$entitySet">
          <xsl:text>,</xsl:text>
        </xsl:if>
        <xsl:text>{"name":"body","in":"body",</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>],"requestBody":{</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>"description":"Action parameters",</xsl:text>
    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>"content":{"application/json":{</xsl:text>
    </xsl:if>
    <xsl:text>"schema":{"type":"object"</xsl:text>
    <xsl:apply-templates select="edm:Parameter[position()>1]" mode="hash">
      <xsl:with-param name="name" select="'properties'" />
    </xsl:apply-templates>
    <xsl:choose>
      <xsl:when test="$openapi-version='2.0'">
        <xsl:text>}}]</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>}}}}</xsl:text>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:call-template name="responses">
      <xsl:with-param name="type" select="edm:ReturnType/@Type" />
    </xsl:call-template>
    <xsl:text>}}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:Function" mode="bound">
    <xsl:param name="entitySet" />
    <xsl:param name="singleton" />
    <xsl:param name="namespace" />
    <xsl:param name="type" />
    <xsl:variable name="singleReturnType">
      <xsl:choose>
        <xsl:when test="starts-with(edm:ReturnType/@Type,'Collection(')">
          <xsl:value-of select="substring-before(substring-after(edm:ReturnType/@Type,'('),')')" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="edm:ReturnType/@Type" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:text>,"/</xsl:text>
    <xsl:choose>
      <xsl:when test="$entitySet">
        <xsl:value-of select="$entitySet" />
        <xsl:apply-templates select="//edm:Schema[@Namespace=$namespace]/edm:EntityType[@Name=$type]" mode="key-in-path" />
      </xsl:when>
      <xsl:when test="$singleton">
        <xsl:value-of select="$singleton" />
      </xsl:when>
    </xsl:choose>
    <xsl:text>/</xsl:text>
    <xsl:choose>
      <xsl:when
        test="../edm:Annotation[(@Term='Org.OData.Core.V1.DefaultNamespace' or @Term=concat($coreAlias,'.DefaultNamespace')) and not(@Qualifier)]" />
      <xsl:when test="../@Alias">
        <xsl:value-of select="../@Alias" />
        <xsl:text>.</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="../@Namespace" />
        <xsl:text>.</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="@Name" />
    <xsl:text>(</xsl:text>
    <xsl:apply-templates select="edm:Parameter[position()>1]" mode="path" />
    <xsl:text>)":{"get":{</xsl:text>
    <xsl:call-template name="summary-description">
      <xsl:with-param name="fallback-summary">
        <xsl:text>Invoke function </xsl:text>
        <xsl:value-of select="@Name" />
      </xsl:with-param>
    </xsl:call-template>
    <xsl:text>,"tags":["</xsl:text>
    <xsl:value-of select="$entitySet" />
    <xsl:value-of select="$singleton" />
    <xsl:text>"],"parameters":[</xsl:text>
    <xsl:apply-templates
      select="//edm:Schema[@Namespace=$namespace and $entitySet]/edm:EntityType[@Name=$type]|edm:Parameter[position()>1]" mode="parameter" />
    <xsl:text>]</xsl:text>

    <xsl:call-template name="responses">
      <xsl:with-param name="type" select="edm:ReturnType/@Type" />
    </xsl:call-template>
    <xsl:text>}}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:Action/edm:Parameter" mode="hashvalue">
    <xsl:call-template name="type">
      <xsl:with-param name="type" select="@Type" />
      <xsl:with-param name="nullableFacet" select="@Nullable" />
    </xsl:call-template>
    <xsl:call-template name="title-description" />
  </xsl:template>

  <xsl:template match="edm:Action/edm:Parameter|edm:Function/edm:Parameter" mode="parameter">
    <xsl:if test="position() > 1">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:text>{"name":"</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:choose>
      <xsl:when test="$odata-version='2.0'">
        <xsl:text>","in":"query"</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>","in":"path"</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>,"required":true,</xsl:text>
    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>"schema":{</xsl:text>
    </xsl:if>
    <xsl:call-template name="type">
      <xsl:with-param name="type" select="@Type" />
      <xsl:with-param name="nullableFacet" select="'false'" />
      <xsl:with-param name="inParameter" select="true()" />
    </xsl:call-template>
    <xsl:if test="$openapi-version!='2.0'">
      <xsl:text>}</xsl:text>
    </xsl:if>
    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template match="edm:Parameter/@MaxLength">
    <xsl:if test=".!='max'">
      <xsl:text>,"maxLength":</xsl:text>
      <xsl:value-of select="." />
    </xsl:if>
  </xsl:template>

  <xsl:template match="edm:Function/edm:Parameter" mode="path">
    <xsl:if test="position()>1">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:value-of select="@Name" />
    <xsl:text>=</xsl:text>
    <xsl:call-template name="pathValueSuffix">
      <xsl:with-param name="type" select="@Type" />
    </xsl:call-template>
    <xsl:text>{</xsl:text>
    <xsl:value-of select="@Name" />
    <xsl:text>}</xsl:text>
    <xsl:call-template name="pathValueSuffix">
      <xsl:with-param name="type" select="@Type" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="title-description">
    <xsl:param name="fallback-title" select="null" />

    <xsl:variable name="title">
      <xsl:call-template name="Common.Label">
        <xsl:with-param name="node" select="." />
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$title!=''">
        <xsl:text>,"title":"</xsl:text>
        <xsl:value-of select="$title" />
        <xsl:text>"</xsl:text>
      </xsl:when>
      <xsl:when test="$fallback-title">
        <xsl:text>,"title":"</xsl:text>
        <xsl:value-of select="$fallback-title" />
        <xsl:text>"</xsl:text>
      </xsl:when>
    </xsl:choose>

    <xsl:variable name="description">
      <xsl:call-template name="description">
        <xsl:with-param name="node" select="." />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="$description!=''">
      <xsl:text>,"description":"</xsl:text>
      <xsl:value-of select="$description" />
      <xsl:text>"</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="summary-description">
    <xsl:param name="fallback-summary" />

    <xsl:variable name="summary">
      <xsl:call-template name="Common.Label">
        <xsl:with-param name="node" select="." />
      </xsl:call-template>
    </xsl:variable>
    <xsl:text>"summary":"</xsl:text>
    <xsl:choose>
      <xsl:when test="$summary!=''">
        <xsl:value-of select="$summary" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$fallback-summary" />
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>"</xsl:text>

    <xsl:variable name="description">
      <xsl:call-template name="description">
        <xsl:with-param name="node" select="." />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="$description!=''">
      <xsl:text>,"description":"</xsl:text>
      <xsl:value-of select="$description" />
      <xsl:text>"</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="description">
    <xsl:param name="node" />
    <xsl:variable name="quickinfo">
      <xsl:call-template name="Common.QuickInfo">
        <xsl:with-param name="node" select="$node" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="description">
      <xsl:call-template name="Core.Description">
        <xsl:with-param name="node" select="$node" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="longdescription">
      <xsl:if test="$property-longDescription">
        <xsl:call-template name="Core.LongDescription">
          <xsl:with-param name="node" select="$node" />
        </xsl:call-template>
      </xsl:if>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$quickinfo!='' or $description!='' or $longdescription!=''">
        <xsl:value-of select="$quickinfo" />
        <xsl:if test="$quickinfo!='' and $description!=''">
          <xsl:text>  \n</xsl:text>
        </xsl:if>
        <xsl:value-of select="$description" />
        <xsl:if test="($quickinfo!='' or $description!='') and $longdescription!=''">
          <xsl:text>  \n</xsl:text>
        </xsl:if>
        <xsl:value-of select="$longdescription" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="Common.Label">
          <xsl:with-param name="node" select="$node" />
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="escape">
    <xsl:param name="string" />
    <xsl:choose>
      <xsl:when test="contains($string,'&quot;')">
        <xsl:call-template name="replace">
          <xsl:with-param name="string" select="$string" />
          <xsl:with-param name="old" select="'&quot;'" />
          <xsl:with-param name="new" select="'\&quot;'" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($string,'\')">
        <xsl:call-template name="replace">
          <xsl:with-param name="string" select="$string" />
          <xsl:with-param name="old" select="'\'" />
          <xsl:with-param name="new" select="'\\'" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($string,'&#x0A;')">
        <xsl:call-template name="replace">
          <xsl:with-param name="string" select="$string" />
          <xsl:with-param name="old" select="'&#x0A;'" />
          <xsl:with-param name="new" select="'\n'" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($string,'&#x0D;')">
        <xsl:call-template name="replace">
          <xsl:with-param name="string" select="$string" />
          <xsl:with-param name="old" select="'&#x0D;'" />
          <xsl:with-param name="new" select="'\r'" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($string,'&#x09;')">
        <xsl:call-template name="replace">
          <xsl:with-param name="string" select="$string" />
          <xsl:with-param name="old" select="'&#x09;'" />
          <xsl:with-param name="new" select="'\t'" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$string" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="replace">
    <xsl:param name="string" />
    <xsl:param name="old" />
    <xsl:param name="new" />
    <xsl:call-template name="escape">
      <xsl:with-param name="string" select="substring-before($string,$old)" />
    </xsl:call-template>
    <xsl:value-of select="$new" />
    <xsl:call-template name="escape">
      <xsl:with-param name="string" select="substring-after($string,$old)" />
    </xsl:call-template>
  </xsl:template>

  <!-- name : object -->
  <xsl:template match="@*|*" mode="object">
    <xsl:param name="name" />
    <xsl:param name="after" select="'something'" />
    <xsl:if test="position()=1">
      <xsl:if test="$after">
        <xsl:text>,</xsl:text>
      </xsl:if>
      <xsl:text>"</xsl:text>
      <xsl:value-of select="$name" />
      <xsl:text>":{</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="." />
    <xsl:if test="position()!=last()">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:if test="position()=last()">
      <xsl:text>}</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- object within array -->
  <xsl:template match="*" mode="item">
    <xsl:text>{</xsl:text>
    <xsl:apply-templates select="@*|node()" mode="list" />
    <xsl:text>}</xsl:text>
  </xsl:template>

  <!-- name: hash -->
  <xsl:template match="*" mode="hash">
    <xsl:param name="name" />
    <xsl:param name="key" select="'Name'" />
    <xsl:param name="after" select="'something'" />
    <xsl:param name="constantProperties" />
    <xsl:if test="position()=1">
      <xsl:if test="$after">
        <xsl:text>,</xsl:text>
      </xsl:if>
      <xsl:text>"</xsl:text>
      <xsl:value-of select="$name" />
      <xsl:text>":{</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="." mode="hashpair">
      <xsl:with-param name="name" select="$name" />
      <xsl:with-param name="key" select="$key" />
    </xsl:apply-templates>
    <xsl:if test="position()!=last()">
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:if test="position()=last()">
      <xsl:value-of select="$constantProperties" />
      <xsl:text>}</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="hashpair">
    <xsl:param name="name" />
    <xsl:param name="key" select="'Name'" />
    <xsl:text>"</xsl:text>
    <xsl:value-of select="@*[local-name()=$key]" />
    <xsl:text>":{</xsl:text>
    <xsl:apply-templates select="." mode="hashvalue">
      <xsl:with-param name="name" select="$name" />
      <xsl:with-param name="key" select="$key" />
    </xsl:apply-templates>
    <xsl:text>}</xsl:text>
  </xsl:template>

  <xsl:template match="*" mode="hashvalue">
    <xsl:param name="key" select="'Name'" />
    <xsl:apply-templates select="@*[local-name()!=$key]|node()" mode="list" />
  </xsl:template>

  <!-- comma-separated list -->
  <xsl:template match="@*|*" mode="list">
    <xsl:param name="target" />
    <xsl:param name="qualifier" />
    <xsl:param name="after" />
    <xsl:choose>
      <xsl:when test="position() > 1">
        <xsl:text>,</xsl:text>
      </xsl:when>
      <xsl:when test="$after">
        <xsl:text>,</xsl:text>
      </xsl:when>
    </xsl:choose>
    <xsl:apply-templates select=".">
      <xsl:with-param name="target" select="$target" />
      <xsl:with-param name="qualifier" select="$qualifier" />
    </xsl:apply-templates>
  </xsl:template>

  <!-- continuation of comma-separated list -->
  <xsl:template match="@*|*" mode="list2">
    <xsl:param name="target" />
    <xsl:param name="qualifier" />
    <xsl:text>,</xsl:text>
    <xsl:apply-templates select=".">
      <xsl:with-param name="target" select="$target" />
      <xsl:with-param name="qualifier" select="$qualifier" />
    </xsl:apply-templates>
  </xsl:template>

  <!-- leftover attributes -->
  <xsl:template match="@*">
    <xsl:text>"TODO:@</xsl:text>
    <xsl:value-of select="local-name()" />
    <xsl:text>":"</xsl:text>
    <xsl:value-of select="." />
    <xsl:text>"</xsl:text>
  </xsl:template>

  <!-- leftover elements -->
  <xsl:template match="*">
    <xsl:text>"TODO:</xsl:text>
    <xsl:value-of select="local-name()" />
    <xsl:text>":{</xsl:text>
    <xsl:apply-templates select="@*|node()" mode="list" />
    <xsl:text>}</xsl:text>
  </xsl:template>

  <!-- leftover text -->
  <xsl:template match="text()">
    <xsl:text>"TODO:text()":"</xsl:text>
    <xsl:value-of select="." />
    <xsl:text>"</xsl:text>
  </xsl:template>

  <!-- helper functions -->
  <xsl:template name="substring-before-last">
    <xsl:param name="input" />
    <xsl:param name="marker" />
    <xsl:if test="contains($input,$marker)">
      <xsl:value-of select="substring-before($input,$marker)" />
      <xsl:if test="contains(substring-after($input,$marker),$marker)">
        <xsl:value-of select="$marker" />
        <xsl:call-template name="substring-before-last">
          <xsl:with-param name="input" select="substring-after($input,$marker)" />
          <xsl:with-param name="marker" select="$marker" />
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <xsl:template name="substring-after-last">
    <xsl:param name="input" />
    <xsl:param name="marker" />
    <xsl:choose>
      <xsl:when test="contains($input,$marker)">
        <xsl:call-template name="substring-after-last">
          <xsl:with-param name="input" select="substring-after($input,$marker)" />
          <xsl:with-param name="marker" select="$marker" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$input" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="replace-all">
    <xsl:param name="string" />
    <xsl:param name="old" />
    <xsl:param name="new" />
    <xsl:choose>
      <xsl:when test="contains($string,$old)">
        <xsl:value-of select="substring-before($string,$old)" />
        <xsl:value-of select="$new" />
        <xsl:call-template name="replace-all">
          <xsl:with-param name="string" select="substring-after($string,$old)" />
          <xsl:with-param name="old" select="$old" />
          <xsl:with-param name="new" select="$new" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$string" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="json-url">
    <xsl:param name="url" />
    <xsl:variable name="jsonUrl">
      <xsl:choose>
        <xsl:when test="substring($url,string-length($url)-3) = '.xml'">
          <xsl:value-of select="substring($url,1,string-length($url)-4)" />
          <xsl:text>.openapi</xsl:text>
          <xsl:if test="$openapi-version!='2.0'">
            <xsl:text>3</xsl:text>
          </xsl:if>
          <xsl:text>.json</xsl:text>
        </xsl:when>
        <xsl:when test="string-length($url) = 0">
          <xsl:value-of select="$url" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$url" />
          <xsl:value-of select="$openapi-formatoption" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="substring($jsonUrl,1,1) = '/'">
        <xsl:value-of select="$scheme" />
        <xsl:text>://</xsl:text>
        <xsl:value-of select="$host" />
        <xsl:value-of select="$jsonUrl" />
      </xsl:when>
      <xsl:when test="substring($jsonUrl,1,3) = '../'">
        <xsl:value-of select="$scheme" />
        <xsl:text>://</xsl:text>
        <xsl:value-of select="$host" />
        <xsl:value-of select="$basePath" />
        <xsl:text>/</xsl:text>
        <xsl:value-of select="$jsonUrl" />
      </xsl:when>
      <!-- TODO: more rules for recognizing relative URLs and doing the needful -->
      <xsl:otherwise>
        <xsl:value-of select="$jsonUrl" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>