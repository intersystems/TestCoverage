Class TestCoverage.Report.Cobertura.Schema
{

Projection ClassGenerator As TestCoverage.Utils.Projection.SchemaGenerator(PACKAGE = "TestCoverage.Report.Cobertura.type");

Parameter VERSION = "2.1.1";

/// Based on https://github.com/cobertura/cobertura/blob/master/cobertura/src/site/htdocs/xml/coverage-loose.dtd
/// Converted from DTD to XSD using Visual Studio's tool for such conversions, then edited to produce the correct
/// projection of list properties (most significantly, using "type" rather than "ref" in sequences representing collections)
XData XSD
{
<?xml version="1.0" encoding="utf-8"?>
<xs:schema xmlns="http://www.intersystems.com/healthshare/tools/coverage" elementFormDefault="qualified" targetNamespace="http://www.intersystems.com/healthshare/tools/coverage" xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="coverage">
    <xs:complexType>
      <xs:sequence>
        <xs:element minOccurs="0" maxOccurs="1" name="sources" type="sources" />
        <xs:element name="packages" type="packages" />
      </xs:sequence>
      <xs:attribute name="line-rate" type="xs:string" />
      <xs:attribute name="branch-rate" type="xs:string" />
      <xs:attribute name="lines-covered" type="xs:string" />
      <xs:attribute name="lines-valid" type="xs:string" />
      <xs:attribute name="branches-covered" type="xs:string" />
      <xs:attribute name="branches-valid" type="xs:string" />
      <xs:attribute name="complexity" type="xs:string" />
      <xs:attribute name="version" type="xs:string" use="required" />
      <xs:attribute name="timestamp" type="xs:string" use="required" />
    </xs:complexType>
  </xs:element>
  <xs:complexType name="sources">
    <xs:sequence>
      <xs:element minOccurs="0" maxOccurs="unbounded" name="source" type="xs:string" />
    </xs:sequence>
  </xs:complexType>
  <xs:complexType name="packages">
    <xs:sequence>
      <xs:element minOccurs="0" maxOccurs="unbounded" name="package" type="package" />
    </xs:sequence>
  </xs:complexType>
  <xs:complexType name="classes">
    <xs:sequence>
      <xs:element minOccurs="0" maxOccurs="unbounded" name="class" type="class" />
    </xs:sequence>
  </xs:complexType>
  <xs:element name="package">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="classes" type="classes" />
      </xs:sequence>
      <xs:attribute name="name" type="xs:string" use="required" />
      <xs:attribute name="line-rate" type="xs:string" />
      <xs:attribute name="branch-rate" type="xs:string" />
      <xs:attribute name="complexity" type="xs:string" />
    </xs:complexType>
  </xs:element>
  <xs:element name="class">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="methods" type="methods" />
        <xs:element name="lines" type="lines" />
      </xs:sequence>
      <xs:attribute name="name" type="xs:string" use="required" />
      <xs:attribute name="filename" type="xs:string" use="required" />
      <xs:attribute name="line-rate" type="xs:string" />
      <xs:attribute name="branch-rate" type="xs:string" />
      <xs:attribute name="complexity" type="xs:string" />
    </xs:complexType>
  </xs:element>
  <xs:complexType name="methods">
    <xs:sequence>
      <xs:element minOccurs="0" maxOccurs="unbounded" name="method" type="method" />
    </xs:sequence>
  </xs:complexType>
  <xs:complexType name="lines">
    <xs:sequence>
      <xs:element minOccurs="0" maxOccurs="unbounded" name="line" type="line" />
    </xs:sequence>
  </xs:complexType>
  <xs:element name="method">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="lines" type="lines" />
      </xs:sequence>
      <xs:attribute name="name" type="xs:string" use="required" />
      <xs:attribute name="signature" type="xs:string" use="required" />
      <xs:attribute name="line-rate" type="xs:string" />
      <xs:attribute name="branch-rate" type="xs:string" />
      <xs:attribute name="complexity" type="xs:string" />
    </xs:complexType>
  </xs:element>
  <xs:element name="line">
    <xs:complexType>
      <xs:sequence>
        <xs:element minOccurs="0" maxOccurs="unbounded" name="conditions" type="conditions" />
      </xs:sequence>
      <xs:attribute name="number" type="xs:string" use="required" />
      <xs:attribute name="hits" type="xs:string" />
      <xs:attribute default="false" name="branch" type="xs:string" />
      <xs:attribute name="condition-coverage" type="xs:string" />
    </xs:complexType>
  </xs:element>
  <xs:complexType name="conditions">
    <xs:sequence>
      <xs:element minOccurs="0" maxOccurs="unbounded" name="condition" type="condition" />
    </xs:sequence>
  </xs:complexType>
  <xs:element name="condition">
    <xs:complexType>
      <xs:attribute name="number" type="xs:string" use="required" />
      <xs:attribute name="type" type="xs:string" use="required" />
      <xs:attribute name="coverage" type="xs:string" use="required" />
    </xs:complexType>
  </xs:element>
</xs:schema>
}

}

