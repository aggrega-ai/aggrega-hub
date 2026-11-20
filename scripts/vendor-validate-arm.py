# scripts/vendor-validate-arm.py — hold Azure Resource Manager templates to the
# template syntax Microsoft documents and to the vendor's own schema for each
# resource type at its apiVersion, offline.
#
# USAGE
#   <python> -I scripts/vendor-validate-arm.py SCHEMAS TEMPLATE...
#
#   SCHEMAS   the schemas directory of Azure/azure-resource-manager-schemas at
#             the commit scripts/vendor-validators.json pins, as
#             scripts/vendor-validate.sh --prime unpacks it into the cache.
#             vendor-validate.sh runs this check with the cache's Python, which
#             holds the pinned jsonschema and referencing, and names this
#             directory.
#   TEMPLATE  a template file, named by the path each finding's id carries:
#             a path relative to the directory the check runs in, and inside
#             it, so no id carries a machine's directory. An absolute path, or
#             one leading out of that directory, is a usage error.
#
# OUTPUT AND EXIT CODES
#   One line per finding: its id, a tab, and what is wrong and what to write
#   instead. The last line is "<N> finding(s)".
#     0  no finding
#     1  findings, each named
#     2  a usage error, a TEMPLATE not named relative to the directory the
#        check runs in, or a TEMPLATE that cannot be read
#     3  no verdict: SCHEMAS holds no schemas, or a schema they reference is
#        missing; the message names the command that primes the cache
#
# FINDING IDS
#   arm|<keyword>|<address>. The address is <template path>/<symbolic name>/
#   <property path>: the property path is the JSON path inside the resource,
#   joined with /. A list-form template has no symbolic names, so its resource
#   is named by its position in resources, from 0. A resource of a nested
#   deployment's template continues its deployment's address,
#   <template path>/<deployment>/properties/template/resources/<name>/..., so
#   the first name after the template path is always a resource of the
#   template itself. A finding about a whole template section is addressed
#   <template path>/<section> (inside a nested template, after its
#   deployment's address). No id carries a line number.
#
#   The keywords:
#     template-json         the file is not a JSON object (addressed
#                           <template path>)
#     template-key          a template key outside the documented sections
#     resources-form        resources written in the other form than the
#                           template's languageVersion takes
#     resource-key          a resource key outside the documented resource
#                           elements and the properties its type's schema
#                           declares
#     no-schema             the pinned schemas hold no definition for the
#                           resource's type at its apiVersion (addressed at
#                           the resource's apiVersion)
#     parameter-key         a parameter a nested deployment passes that its
#                           template does not declare, or one its template
#                           requires that it does not pass (addressed
#                           <deployment>/properties/parameters/<name>)
#     parameter-value       a parameter a nested deployment passes that its
#                           template's declaration refuses (addressed as
#                           parameter-key)
#   and, for a resource body, the JSON Schema (draft 4) keyword the value
#   fails: type, enum, required, additionalProperties, pattern, minLength,
#   maxLength, minimum, maximum, multipleOf, minItems, maxItems, uniqueItems,
#   minProperties, maxProperties, additionalItems, dependencies, not, anyOf.
#   additionalProperties names a property the schema does not list, whether the
#   schema closes the object itself or the closed-object reading below does;
#   anyOf names a value no alternative of a union accepts, and its message
#   names the nearest alternative's failure.
#
# WHY NOT THE VENDOR'S TEMPLATE SCHEMA. The vendor publishes an envelope schema,
# schemas/2019-04-01/deploymentTemplate.json, and it cannot read the templates
# this catalog renders. It closes the top level (additionalProperties false)
# over $schema, apiProfile, contentVersion, functions, metadata, outputs,
# parameters, resources and variables: languageVersion and definitions are not
# among them, and existing appears nowhere in it. Every template the arm
# provider renders is languageVersion 2.0, and the Azure Verified Modules the
# catalog's arm Recipes wrap carry languageVersion, definitions and existing
# resources.
#
# THE ENVELOPE, written from Microsoft Learn's page "Understand the structure
# and syntax of ARM templates"
# (https://learn.microsoft.com/azure/azure-resource-manager/templates/syntax):
#   - the template's keys are within its sections: $schema, languageVersion,
#     contentVersion, apiProfile, definitions, parameters, variables,
#     functions, resources, outputs and metadata;
#   - with languageVersion 2.0 or later, resources is an object keyed by
#     symbolic name; otherwise it is a list;
#   - each resource's keys are within the page's resource elements (condition,
#     type, apiVersion, name, comments, location, dependsOn, tags, identity,
#     sku, kind, scope, copy, plan, properties, resources), the reference form
#     languageVersion 2.0 adds (existing, resourceGroup, subscriptionId),
#     metadata, which the page allows on a resource, and the properties the
#     type's own schema declares at its top. The keys of a resource whose type
#     the pinned schemas do not cover are not read: its no-schema finding
#     stands for it, and no key its schema would declare is refused.
#
# THE BODY. Each resource is validated against the vendor's definition of its
# type at its apiVersion, schemas/<apiVersion>/<Namespace>.json under one of
# its *resourceDefinitions, keyed by the type after the namespace with each /
# written _ (Microsoft.App/containerApps/authConfigs: Microsoft.App.json,
# containerApps_authConfigs); type, namespace and apiVersion compare without
# case, as Resource Manager reads them. A type defined at several deployment
# scopes is read at the scope the template's $schema names
# (deploymentTemplate.json a resource group, subscriptionDeploymentTemplate.json
# a subscription, managementGroupDeploymentTemplate.json a management group,
# tenantDeploymentTemplate.json a tenant), else at the first of resource group,
# extension, subscription, management group and tenant that defines it.
#   - The body is the resource's elements and the properties its type's
#     schema declares, less the elements that belong to the template language
#     and not to the resource (condition, comments, dependsOn, copy, scope,
#     existing, resourceGroup, subscriptionId, metadata) unless the schema
#     declares one. A key outside the envelope is the envelope's finding
#     alone. A child resource listed under resources has the template-language
#     elements set aside the same way, and the schema's own definition of the
#     child reads the rest.
#   - An existing resource is a reference to a resource deployed elsewhere: it
#     carries no body, so only the envelope reads it.
#   - A Microsoft.Resources/deployments resource whose properties.template is
#     written inline is a template too: both the envelope and the body read it,
#     and every deployment nested in it, to any depth.
#   - A type or apiVersion the pinned schemas lack is a finding naming
#     type@apiVersion, the newest apiVersions they cover for the type, and the
#     remedy: write one of those, or move the arm_schemas pin.
#
# THE PARAMETERS, written from Microsoft Learn's pages "Parameters in templates"
# (https://learn.microsoft.com/azure/azure-resource-manager/templates/parameters)
# and "Link templates for deployment"
# (https://learn.microsoft.com/azure/azure-resource-manager/templates/linked-templates).
# A nested deployment whose template is written inline, and whose expressions
# are evaluated in its own scope, passes its template's parameters in
# properties.parameters, and Resource Manager holds them to the template's
# declarations when it validates that deployment. The scope is its own where
# properties.expressionEvaluationOptions.scope is inner, and, with no scope
# written, where the template holding the deployment is languageVersion 2.0 or
# later, which allows no other. Parameter names and type names compare without
# case.
#   - Each parameter passed is one the template declares (parameter-key).
#   - Each parameter the template declares with no defaultValue, and not
#     nullable, is passed (parameter-key).
#   - Each entry passed is {"value": ...}, a Key Vault reference,
#     {"reference": ...}, which Resource Manager resolves when it deploys and
#     which is not read further, or an expression, as Bicep writes an entry
#     passed only under a condition (parameter-value).
#   - A value written as a literal, not wholly as an expression (rule 3 below),
#     meets the declaration (parameter-value): its type, string, securestring,
#     int, bool, object, secureobject or array, a JSON number written with a
#     fraction or an exponent being no int; its allowedValues, each item of an
#     array not written as an expression, strings compared without case as
#     rule 1 compares enum strings; minValue and maxValue for an int; minLength
#     and maxLength for a string or an array. A declaration naming a type its
#     definitions declare, by $ref, is read with that definition under it.
#
# THE READING RULES. Read as written, the vendor's schemas refuse templates
# Resource Manager deploys, and pass misspelt properties it refuses. These
# rules read them as Resource Manager does:
#   1. Enum strings compare without case. The schemas and the compilers write
#      enum values in different cases: the schemas write Inner where Bicep
#      writes inner, which Resource Manager deploys.
#   2. oneOf is read as anyOf. The schemas pair alternatives that overlap: a
#      deployment parameter's value is any value or an expression, so an
#      expression matches both and oneOf, requiring exactly one, refuses it.
#   3. A value written wholly as an expression is accepted wherever it
#      appears: a string that opens with [ and closes with ], unless it opens
#      with [[, the escape for a literal string. Resource Manager evaluates it
#      at deployment, so nothing offline knows its value, and compiled
#      templates write whole properties, objects and parameter entries so. With
#      that, the schemas' own expression alternative (the expression definition
#      of common/definitions.json) accepts nothing more, and is set aside, so a
#      literal of the wrong type is named by its typed alternative's keyword.
#   4. Objects are closed. The schemas leave objects open: an object schema
#      listing its properties seldom sets additionalProperties, so a misspelt
#      property passes. An object is read with additionalProperties false over
#      every property the schemas describing it list, followed through $ref,
#      allOf and the alternatives of a union, so a type composed from several
#      schemas keeps every property any of them lists. It stays open where one
#      of those schemas allows other properties (additionalProperties true or a
#      schema) or an alternative of a union accepts any object; an
#      additionalProperties false the vendor writes is read as written. ARM's
#      property iteration, copy, is allowed in any object, and the properties a
#      copy names count as present.
#   5. A property a resource provider takes and its specification omits is
#      listed. The schemas are generated from each provider's OpenAPI
#      specification, and a provider can take a property before its
#      specification lists it, which rule 4 would refuse. DOCUMENTED_PROPERTIES
#      names each such property by its type, its apiVersion and its path in the
#      resource, beside the provider's documentation of it. There, and only
#      there, the property is not refused as unlisted, and its value is not
#      checked. An apiVersion is listed once a template carries the property at
#      it. Listed:
#        Microsoft.CognitiveServices/accounts/deployments@2026-05-01,
#        properties.modelProviderData: the model-provider attestation the
#        provider takes for a partner model, set out under "Terms of use" on
#        Microsoft Learn's page "Deploy and use Claude on Microsoft Foundry
#        using Bicep or Terraform via Azure Developer CLI"
#        (https://learn.microsoft.com/azure/developer/ai/how-to/deploy-claude-foundry#terms-of-use),
#        and missing from the specification
#        (https://github.com/Azure/azure-rest-api-specs/issues/43610). The
#        Azure Verified Modules module avm/res/cognitive-services/account writes
#        it on every model deployment from version 0.19.0, as an expression
#        over a parameter of its own. Measured: the pinned schemas list it at
#        no apiVersion of the type and leave the object holding it open, so
#        without this entry rule 4 alone refuses it.
#
# LIMITS. What the check passes that Resource Manager refuses, and where it is
# stricter than Resource Manager:
#   - Parameters are read only as THE PARAMETERS says: a deployment whose
#     template is linked, which passes its parameters by parametersLink, or
#     whose expressions are evaluated in its parent's scope (outer) is not
#     held to them; a null value, and the members of an object or an array,
#     are not held to the declaration (its properties, items, discriminator or
#     additionalProperties); a Key Vault reference is not held to the
#     declared type.
#   - A child resource listed under a resource's own resources is read by its
#     parent's schema alone: its keys are not held to the resource elements,
#     and a nested deployment among them is not read as a template.
#   - Stricter: where the vendor writes additionalProperties false on the base
#     of a discriminated union inside allOf, a property only a subtype lists is
#     refused, as in Microsoft.EventGrid/topics/eventSubscriptions' destination.
#   - Stricter: a child resource declared outside its parent with a literal
#     name, parent/child, fails the type's name pattern, which matches the
#     child's name alone; written as an expression, as Bicep and the catalog's
#     arm Recipes write it, format('{0}/{1}', ...), it passes by rule 3.
#
# OFFLINE. Every schema is read from SCHEMAS: a $ref names
# https://schema.management.azure.com/schemas/<path>, which is read from
# SCHEMAS/<path>, and any other reference is unresolvable. Nothing here opens a
# network connection.

import json
import os
import posixpath
import re
import sys

import referencing
import referencing.exceptions
import referencing.jsonschema
from jsonschema import Draft4Validator, validators
from jsonschema.exceptions import ValidationError, best_match

ME = "vendor-validate-arm"
SCHEMA_HOSTS = ("https://schema.management.azure.com/schemas/", "http://schema.management.azure.com/schemas/")
EXPRESSION_REF = SCHEMA_HOSTS[0] + "common/definitions.json#/definitions/expression"
LEARN_PAGE = '"Understand the structure and syntax of ARM templates" (https://learn.microsoft.com/azure/azure-resource-manager/templates/syntax)'
PARAMETERS_PAGE = '"Parameters in templates" (https://learn.microsoft.com/azure/azure-resource-manager/templates/parameters)'

TEMPLATE_KEYS = ("$schema", "languageVersion", "contentVersion", "apiProfile", "definitions", "parameters",
                 "variables", "functions", "resources", "outputs", "metadata")
RESOURCE_ELEMENTS = ("condition", "type", "apiVersion", "name", "comments", "location", "dependsOn", "tags",
                     "identity", "sku", "kind", "scope", "copy", "plan", "properties", "resources")
REFERENCE_KEYS = ("existing", "resourceGroup", "subscriptionId")
TEMPLATE_LANGUAGE_KEYS = ("condition", "comments", "dependsOn", "copy", "scope", "existing", "resourceGroup",
                          "subscriptionId", "metadata")
DEPLOYMENTS = "microsoft.resources/deployments"
# The parameter types a template declares, by their names in lower case.
PARAMETER_TYPES = {"string": str, "securestring": str, "int": int, "bool": bool, "object": dict,
                   "secureobject": dict, "array": list}

# Rule 5: each property a resource provider takes and its specification omits,
# keyed by the type and apiVersion it is taken at, in lower case, then by its
# path in the resource, with the provider's documentation of it.
DOCUMENTED_PROPERTIES = {
    ("microsoft.cognitiveservices/accounts/deployments", "2026-05-01"): {
        ("properties", "modelProviderData"):
            "https://learn.microsoft.com/azure/developer/ai/how-to/deploy-claude-foundry#terms-of-use",
    },
}

# The *resourceDefinitions key a template's $schema names, by the file it names.
SCOPE_BY_SCHEMA = {
    "deploymenttemplate.json": "resourceDefinitions",
    "subscriptiondeploymenttemplate.json": "subscription_resourceDefinitions",
    "managementgroupdeploymenttemplate.json": "managementGroup_resourceDefinitions",
    "tenantdeploymenttemplate.json": "tenant_resourceDefinitions",
}
SCOPE_ORDER = ("resourceDefinitions", "extension_resourceDefinitions", "subscription_resourceDefinitions",
               "managementGroup_resourceDefinitions", "tenant_resourceDefinitions")
API_VERSION_DIR = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}(-[A-Za-z0-9.]+)?")
LANGUAGE_VERSION = re.compile(r"\s*([0-9]+)(\.|$)")


class NoVerdict(Exception):
    """The schemas cannot answer: the cache is missing or incomplete."""


def is_expression(value):
    """Whether VALUE is written wholly as an ARM expression (reading rule 3)."""
    return isinstance(value, str) and len(value) >= 2 and value[0] == "[" and value[-1] == "]" \
        and not value.startswith("[[")


def join_ref(base, ref):
    """REF made absolute against BASE, a schema document's URI."""
    if "://" in ref.partition("#")[0]:
        return ref
    if ref.startswith("#"):
        return base + ref
    path, _, fragment = ref.partition("#")
    joined = posixpath.normpath(posixpath.join(posixpath.dirname(base.split("://", 1)[1]), path))
    return base.split("://", 1)[0] + "://" + joined + ("#" + fragment if fragment else "")


def property_copies(instance):
    """The property names an object's ARM property iteration (copy) produces."""
    copies = instance.get("copy") if isinstance(instance, dict) else None
    if not isinstance(copies, list):
        return set()
    return {c["name"] for c in copies if isinstance(c, dict) and isinstance(c.get("name"), str)}


class Schemas:
    """The vendor's schemas, read from the cache and read by the rules above."""

    def __init__(self, root):
        self.root = os.path.realpath(root)
        if not os.path.isfile(os.path.join(self.root, "common", "definitions.json")):
            raise NoVerdict(f"{root} holds no Azure Resource Manager schemas")
        self.documents = {}
        self.listings = {}
        self.shapes = {}
        self.registry = referencing.Registry(retrieve=self._retrieve)

    # --- reading documents ---------------------------------------------------
    def _path(self, uri):
        for host in SCHEMA_HOSTS:
            if uri.startswith(host):
                path = os.path.realpath(os.path.join(self.root, uri[len(host):]))
                if os.path.commonpath([path, self.root]) == self.root:
                    return path
        raise NoVerdict(f"a schema references {uri}, which is not among the schemas the cache holds")

    def document(self, uri):
        """The document at URI (no fragment), read as the reading rules read it."""
        if uri not in self.documents:
            path = self._path(uri)
            try:
                with open(path, encoding="utf-8") as f:
                    contents = json.load(f)
            except (OSError, ValueError) as e:
                raise NoVerdict(f"the schema {path} cannot be read ({e})") from e
            self.documents[uri] = self._read_schema(contents, uri, root=True)
        return self.documents[uri]

    def _retrieve(self, uri):
        try:
            contents = self.document(uri)
        except NoVerdict as e:
            raise referencing.exceptions.NoSuchResource(ref=uri) from e
        return referencing.jsonschema.DRAFT4.create_resource(contents)

    def lookup(self, ref):
        """The schema an absolute REF points at."""
        uri, _, fragment = ref.partition("#")
        node = self.document(uri)
        for part in fragment.split("/")[1:] if fragment else ():
            part = part.replace("~1", "/").replace("~0", "~")
            try:
                node = node[int(part)] if isinstance(node, list) else node[part]
            except (KeyError, IndexError, ValueError, TypeError) as e:
                raise NoVerdict(f"the schema reference {ref} points at nothing") from e
        return node

    def _read_schema(self, schema, base, root=False):
        """SCHEMA with every $ref absolute, its id dropped (the references no
        longer depend on it), and its unions read by rules 2 and 3."""
        if not isinstance(schema, dict):
            return schema
        out = {}
        for key, value in schema.items():
            if key == "id" and isinstance(value, str):
                continue
            if key == "$ref" and isinstance(value, str):
                out[key] = join_ref(base, value)
            elif (key in ("properties", "patternProperties", "definitions", "dependencies")
                  or (root and key.endswith("resourceDefinitions"))) and isinstance(value, dict):
                out[key] = {k: self._read_schema(v, base) for k, v in value.items()}
            elif key in ("allOf", "anyOf", "oneOf", "items") and isinstance(value, list):
                out[key] = [self._read_schema(v, base) for v in value]
            elif key in ("items", "additionalProperties", "additionalItems", "not"):
                out[key] = self._read_schema(value, base)
            else:
                out[key] = value
        # Rule 2, oneOf read as anyOf, and rule 3, the expression alternative
        # set aside. A union left with one alternative is that alternative.
        conjuncts = list(out.pop("allOf", []))
        unions = []
        for key in ("oneOf", "anyOf"):
            if key in out:
                alternatives = out.pop(key)
                kept = [a for a in alternatives if not (isinstance(a, dict) and a.get("$ref") == EXPRESSION_REF)]
                kept = kept or alternatives
                if len(kept) == 1:
                    conjuncts.append(kept[0])
                else:
                    unions.append(kept)
        if len(unions) == 1:
            out["anyOf"] = unions[0]
        else:
            conjuncts.extend({"anyOf": u} for u in unions)
        if conjuncts:
            out["allOf"] = conjuncts
        return out

    # --- rule 4: the closed reading ------------------------------------------
    def shape(self, schema):
        """(names, patterns, closed) for an object SCHEMA describes: the
        properties listed through $ref, allOf and union alternatives, their
        property patterns, and whether the object is read closed (rule 4)."""
        key = id(schema)
        if key in self.shapes:
            return self.shapes[key]
        names, patterns = set(), []
        lists = opened = False
        seen = set()
        stack = [(schema, False)]
        while stack:
            s, alternative = stack.pop()
            if not isinstance(s, dict) or id(s) in seen:
                continue
            seen.add(id(s))
            if "$ref" in s:
                stack.append((self.lookup(s["$ref"]), alternative))
                continue
            if "properties" in s:
                lists = True
                names.update(s["properties"])
            patterns.extend(s.get("patternProperties", ()))
            if "additionalProperties" in s and s["additionalProperties"] is not False:
                opened = True
            if alternative and accepts_any_object(s):
                opened = True
            stack.extend((c, False) for c in s.get("allOf", ()))
            stack.extend((a, True) for a in s.get("anyOf", ()))
        self.shapes[key] = result = (names, patterns, lists and not opened)
        return result

    # --- finding a type's definition -----------------------------------------
    def _listing(self, directory):
        """The entries of DIRECTORY under the schemas, keyed in lower case."""
        if directory not in self.listings:
            path = os.path.join(self.root, directory) if directory else self.root
            try:
                names = sorted(os.listdir(path))
            except OSError:
                names = []
            self.listings[directory] = {n.lower(): n for n in names}
        return self.listings[directory]

    def definition_ref(self, type_, api_version, scope):
        """The absolute $ref of TYPE's definition at API_VERSION, or None."""
        namespace, _, rest = type_.partition("/")
        if not namespace or not rest:
            return None
        directory = self._listing("").get(api_version.lower())
        if directory is None:
            return None
        filename = self._listing(directory).get(namespace.lower() + ".json")
        if filename is None:
            return None
        uri = SCHEMA_HOSTS[0] + directory + "/" + filename
        document = self.document(uri)
        wanted = rest.replace("/", "_").lower()
        groups = [scope] + [g for g in SCOPE_ORDER if g != scope]
        groups += [g for g in document if g.endswith("resourceDefinitions") and g not in groups]
        for group in groups:
            definitions = document.get(group)
            if not isinstance(definitions, dict):
                continue
            for name in definitions:
                if name.lower() == wanted:
                    return f"{uri}#/{group}/{name}"
        return None

    def covered_api_versions(self, type_, limit=3):
        """The newest apiVersions the schemas define TYPE at, newest first."""
        namespace, _, rest = type_.partition("/")
        wanted = rest.replace("/", "_").lower()
        found = []
        for directory in sorted(self._listing("").values(), reverse=True):
            if not API_VERSION_DIR.fullmatch(directory):
                continue
            filename = self._listing(directory).get(namespace.lower() + ".json")
            if filename is None:
                continue
            try:
                with open(os.path.join(self.root, directory, filename), encoding="utf-8") as f:
                    document = json.load(f)
            except (OSError, ValueError):
                continue
            if any(isinstance(v, dict) and wanted in (n.lower() for n in v)
                   for k, v in document.items() if k.endswith("resourceDefinitions")):
                found.append(directory)
                if len(found) == limit:
                    break
        return found


def accepts_any_object(schema):
    """Whether a union alternative accepts every object: it lists nothing,
    composes nothing and admits the object type."""
    if any(k in schema for k in ("properties", "patternProperties", "additionalProperties", "allOf", "anyOf",
                                 "$ref", "enum", "not", "required", "minProperties", "maxProperties")):
        return False
    kind = schema.get("type")
    return kind is None or kind == "object" or (isinstance(kind, list) and "object" in kind)


def arm_validator(schemas):
    """A draft 4 validator reading the vendor's schemas by the reading rules."""
    base = Draft4Validator.VALIDATORS

    def unlisted(instance, schema, path):
        # Rule 4: the properties of INSTANCE, at PATH, that no schema
        # applying to it lists.
        if not isinstance(instance, dict):
            return
        names, patterns, closed = schemas.shape(schema)
        if not closed:
            return
        for key in instance:
            if key == "copy" or key in names or any(re.search(p, key) for p in patterns):
                continue
            yield ValidationError(f"{key!r} is not a property the schema lists here",
                                  validator="additionalProperties", validator_value=False,
                                  instance=instance, schema=schema, path=[*path, key])

    def properties(validator, properties, instance, schema):
        if not validator.is_type(instance, "object"):
            return
        for name, subschema in properties.items():
            if name in instance:
                yield from validator.descend(instance[name], subschema, path=name, schema_path=name)
                yield from unlisted(instance[name], subschema, (name,))

    def pattern_properties(validator, patterns, instance, schema):
        if not validator.is_type(instance, "object"):
            return
        for pattern, subschema in patterns.items():
            for name, value in instance.items():
                if re.search(pattern, name):
                    yield from validator.descend(value, subschema, path=name, schema_path=pattern)
                    yield from unlisted(value, subschema, (name,))

    def additional_properties(validator, additional, instance, schema):
        if not validator.is_type(instance, "object"):
            return
        listed = schema.get("properties", {})
        patterns = schema.get("patternProperties", {})
        extras = [k for k in instance
                  if k != "copy" and k not in listed and not any(re.search(p, k) for p in patterns)]
        if isinstance(additional, dict):
            for name in extras:
                yield from validator.descend(instance[name], additional, path=name)
                yield from unlisted(instance[name], additional, (name,))
        elif additional is False:
            for name in extras:
                yield ValidationError(f"{name!r} is not a property the schema lists here", path=[name])

    def items(validator, items, instance, schema):
        if not validator.is_type(instance, "array"):
            return
        if isinstance(items, dict):
            for index, item in enumerate(instance):
                yield from validator.descend(item, items, path=index)
                yield from unlisted(item, items, (index,))
        else:
            for (index, item), subschema in zip(enumerate(instance), items):
                yield from validator.descend(item, subschema, path=index, schema_path=index)
                yield from unlisted(item, subschema, (index,))

    def required(validator, required, instance, schema):
        if not validator.is_type(instance, "object"):
            return
        produced = property_copies(instance)
        for name in required:
            if name not in instance and name not in produced:
                yield ValidationError(f"{name!r} is a required property", path=[name])

    def enum(validator, enums, instance, schema):
        # Rule 1: an enum string compares without case.
        if isinstance(instance, str):
            folded = instance.lower()
            if not any(isinstance(e, str) and e.lower() == folded for e in enums):
                yield ValidationError(f"{instance!r} is not one of {enums!r}")
            return
        yield from base["enum"](validator, enums, instance, schema)

    def accepting_expressions(keyword):
        # Rule 3: a value written wholly as an expression meets every keyword.
        def read(validator, value, instance, schema):
            if is_expression(instance):
                return
            errors = keyword(validator, value, instance, schema)
            if errors is not None:
                yield from errors
        return read

    keywords = dict(base)
    keywords.update({
        "properties": properties,
        "patternProperties": pattern_properties,
        "additionalProperties": additional_properties,
        "items": items,
        "required": required,
        "enum": enum,
    })
    cls = validators.extend(Draft4Validator, {k: accepting_expressions(v) for k, v in keywords.items()})
    return cls, unlisted


class Check:
    def __init__(self, schemas):
        self.schemas = schemas
        self.validator_class, self.unlisted = arm_validator(schemas)
        self.findings = []
        self.seen = set()

    def find(self, keyword, address, message):
        finding_id = f"arm|{keyword}|{address}"
        if finding_id not in self.seen:
            self.seen.add(finding_id)
            self.findings.append(f"{finding_id}\t{message}")

    def template(self, template, prefix, nested=False):
        """Reads TEMPLATE, addressed PREFIX, by the envelope and the body. A
        nested template's resources are addressed by their JSON path."""
        for key in template:
            if key not in TEMPLATE_KEYS:
                self.find("template-key", f"{prefix}/{key}",
                          f"{key!r} is not a section of an ARM template: the sections are "
                          f"{', '.join(TEMPLATE_KEYS)} ({LEARN_PAGE}).")
        match = LANGUAGE_VERSION.match(str(template.get("languageVersion", "")))
        symbolic = bool(match) and int(match.group(1)) >= 2
        resources = template.get("resources")
        if resources is None:
            return
        if symbolic and not isinstance(resources, dict):
            self.find("resources-form", f"{prefix}/resources",
                      "with languageVersion 2.0 or later, resources is an object keyed by symbolic name.")
        elif not symbolic and not isinstance(resources, list):
            self.find("resources-form", f"{prefix}/resources",
                      "without languageVersion 2.0 or later, resources is a list; an object keyed by symbolic "
                      "name needs \"languageVersion\": \"2.0\".")
        schema_file = str(template.get("$schema", "")).split("#", 1)[0].rsplit("/", 1)[-1].lower()
        scope = SCOPE_BY_SCHEMA.get(schema_file, "resourceDefinitions")
        entries = resources.items() if isinstance(resources, dict) else enumerate(resources) \
            if isinstance(resources, list) else ()
        resource_prefix = f"{prefix}/resources" if nested else prefix
        for name, resource in entries:
            self.resource(resource, f"{resource_prefix}/{name}", scope, symbolic)

    def resource(self, resource, address, scope, symbolic):
        if not isinstance(resource, dict):
            self.find("resource-key", address, "a resource is a JSON object.")
            return
        type_, api_version = resource.get("type"), resource.get("apiVersion")
        existing = resource.get("existing") is True
        allowed = set(RESOURCE_ELEMENTS) | set(REFERENCE_KEYS) | {"metadata"}
        ref = None
        literal = isinstance(type_, str) and isinstance(api_version, str) \
            and not is_expression(type_) and not is_expression(api_version)
        if not existing:
            if literal:
                ref = self.schemas.definition_ref(type_, api_version, scope)
            if ref is None:
                self.no_schema(address, type_, api_version, literal)
            else:
                allowed |= self.schemas.shape(self.schemas.lookup(ref))[0]
        if existing or ref is not None:
            for key in resource:
                if key not in allowed:
                    declared = f" and the properties the {type_}@{api_version} schema declares" if ref else ""
                    self.find("resource-key", f"{address}/{key}",
                              f"{key!r} is not a resource element: the elements are {', '.join(RESOURCE_ELEMENTS)}, "
                              f"the reference form {', '.join(REFERENCE_KEYS)}, metadata{declared} ({LEARN_PAGE}).")
        if ref is None:
            return
        documented = DOCUMENTED_PROPERTIES.get((type_.lower(), api_version.lower()), {})
        self.body(resource, address, ref, f"{type_}@{api_version}", documented)
        properties = resource.get("properties")
        if type_.lower() == DEPLOYMENTS and isinstance(properties, dict) \
                and isinstance(properties.get("template"), dict):
            if evaluated_inner(properties, symbolic):
                self.parameters(properties, address)
            self.template(properties["template"], f"{address}/properties/template", nested=True)

    def no_schema(self, address, type_, api_version, literal):
        if not literal:
            self.find("no-schema", f"{address}/apiVersion",
                      "the resource does not write its type and apiVersion as literal strings, and its schema is "
                      "read by them: write both literally.")
            return
        covered = self.schemas.covered_api_versions(type_)
        newest = (f"the newest they cover: {', '.join(covered)}" if covered
                  else "they cover no apiVersion of this type")
        self.find("no-schema", f"{address}/apiVersion",
                  f"{type_}@{api_version}: the pinned Azure Resource Manager schemas define no {type_} at "
                  f"apiVersion {api_version} ({newest}). Write an apiVersion they cover, or move the arm_schemas "
                  f"pin in scripts/vendor-validators.json to a commit that covers this one.")

    def body(self, resource, address, ref, label, documented):
        """Validates RESOURCE against its type's definition at REF. DOCUMENTED
        holds the paths of the properties rule 5 lists for its type and
        apiVersion: none of them is refused as unlisted."""
        schema = self.schemas.lookup(ref)
        body = resource_body(resource, self.schemas.shape(schema)[0])
        validator = self.validator_class({"$ref": ref}, registry=self.schemas.registry)
        errors = list(validator.iter_errors(body)) + list(self.unlisted(body, schema, ()))
        for error in errors:
            if error.validator == "additionalProperties" and tuple(error.absolute_path) in documented:
                continue
            at = at_address(address, error)
            message = brief(error)
            if error.validator == "anyOf" and error.context:
                nearest = best_match(error.context)
                message = (f"no alternative the schema allows accepts this value; the nearest: {brief(nearest)}"
                           f" at {at_address(address, nearest)}")
            self.find(error.validator, at, f"{message} ({label}).")

    def parameters(self, properties, address):
        """Holds the parameters a nested deployment, at ADDRESS, passes to those
        its inline template declares (THE PARAMETERS)."""
        template = properties["template"]
        passed, declared = properties.get("parameters", {}), template.get("parameters", {})
        if "parametersLink" in properties or not isinstance(passed, dict) or not isinstance(declared, dict):
            return
        definitions = template.get("definitions")
        definitions = definitions if isinstance(definitions, dict) else {}
        by_name = {k.lower(): k for k in declared}
        passed_names = {k.lower() for k in passed}
        at = f"{address}/properties/parameters"
        for name, entry in passed.items():
            if name.lower() not in by_name:
                self.find("parameter-key", f"{at}/{name}",
                          f"{name!r} is passed, and the nested template declares no such parameter: a deployment "
                          f"passes only the parameters its template declares ({PARAMETERS_PAGE}).")
                continue
            problem = entry_problem(entry, declaration(declared[by_name[name.lower()]], definitions))
            if problem:
                self.find("parameter-value", f"{at}/{name}", f"{problem} ({PARAMETERS_PAGE}).")
        for name, declared_as in declared.items():
            d = declaration(declared_as, definitions)
            if name.lower() in passed_names or "defaultValue" in d or d.get("nullable") is True:
                continue
            self.find("parameter-key", f"{at}/{name}",
                      f"the nested template declares {name!r} with no defaultValue and not nullable, so it is "
                      f"required, and the deployment does not pass it ({PARAMETERS_PAGE}).")

    def run(self, path, display):
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except (OSError, UnicodeDecodeError) as e:
            raise UsageError(f"cannot read the template {display}: {e}") from e
        try:
            template = json.loads(text)
        except ValueError as e:
            self.find("template-json", display, f"the template is not JSON: {e}.")
            return
        if not isinstance(template, dict):
            self.find("template-json", display, "the template is not a JSON object.")
            return
        self.template(template, display)


def at_address(address, error):
    """The address of the value ERROR names, inside the resource at ADDRESS."""
    return "/".join([address, *(str(p) for p in error.absolute_path)])


def brief(error):
    """ERROR's message, with a long value it quotes shortened."""
    quoted = repr(error.instance)
    if len(quoted) <= 80 or quoted not in error.message:
        return error.message
    return error.message.replace(quoted, quoted[:60] + " …" + quoted[-1])


def evaluated_inner(properties, symbolic):
    """Whether a nested deployment's expressions are evaluated in its own
    scope: scope inner, or no scope written in a template, SYMBOLIC, of
    languageVersion 2.0 or later."""
    options = properties.get("expressionEvaluationOptions")
    scope = options.get("scope") if isinstance(options, dict) else None
    if scope is None:
        return symbolic
    return isinstance(scope, str) and scope.lower() == "inner"


def declaration(declared, definitions):
    """A parameter's declaration, DECLARED, over the definition its $ref names
    in DEFINITIONS, followed to any depth; its own keys win."""
    chain, seen, d = [], set(), declared
    while isinstance(d, dict):
        chain.append(d)
        ref = d.get("$ref")
        if not isinstance(ref, str) or not ref.startswith("#/definitions/") or ref in seen:
            break
        seen.add(ref)
        d = definitions.get(ref[len("#/definitions/"):])
    merged = {}
    for d in reversed(chain):
        merged.update(d)
    return merged


def shortened(value):
    """VALUE as JSON, shortened when long."""
    text = json.dumps(value)
    return text if len(text) <= 80 else text[:60] + " …" + text[-1]


def same_value(value, allowed):
    """Whether VALUE is the allowed value ALLOWED: strings compare without
    case; a boolean equals only a boolean."""
    if isinstance(value, str) and isinstance(allowed, str):
        return value.lower() == allowed.lower()
    if isinstance(value, bool) or isinstance(allowed, bool):
        return type(value) is type(allowed) and value == allowed
    return value == allowed


def entry_problem(entry, d):
    """What the declaration D refuses in a parameter ENTRY a deployment
    passes, or None."""
    if is_expression(entry):
        return None
    if not isinstance(entry, dict) or not ("value" in entry or "reference" in entry):
        return ('a parameter a deployment passes is {"value": ...}, or a Key Vault reference, '
                '{"reference": ...}')
    if "value" not in entry:
        return None
    value = entry["value"]
    if value is None or is_expression(value):
        return None
    kind = d.get("type")
    expected = PARAMETER_TYPES.get(kind.lower()) if isinstance(kind, str) else None
    if expected is not None and (not isinstance(value, expected)
                                 or (expected is int and isinstance(value, bool))):
        return f"{shortened(value)} is not of the type {kind} the nested template declares for this parameter"
    allowed = d.get("allowedValues")
    if isinstance(allowed, list):
        items = value if isinstance(value, list) and expected is list else [value]
        for item in items:
            if is_expression(item):
                continue
            if not any(same_value(item, a) for a in allowed):
                return f"{shortened(item)} is not one of the allowedValues the nested template declares, {shortened(allowed)}"
    number = isinstance(value, int) and not isinstance(value, bool)
    sized = isinstance(value, (str, list))
    for key, applies, measure, refused in (
            ("minValue", number, value, lambda m, b: m < b),
            ("maxValue", number, value, lambda m, b: m > b),
            ("minLength", sized, len(value) if sized else 0, lambda m, b: m < b),
            ("maxLength", sized, len(value) if sized else 0, lambda m, b: m > b)):
        bound = d.get(key)
        if applies and isinstance(bound, int) and not isinstance(bound, bool) and refused(measure, bound):
            return f"{shortened(value)} is outside the {key}, {bound}, the nested template declares"
    return None


def resource_body(resource, declared):
    """What the schema reads of RESOURCE: its elements and the properties
    DECLARED, less the template-language elements not declared."""
    body = {k: v for k, v in resource.items()
            if k in declared or (k in RESOURCE_ELEMENTS and k not in TEMPLATE_LANGUAGE_KEYS)}
    children = body.get("resources")
    if isinstance(children, list):
        body["resources"] = [child_body(c) for c in children]
    return body


def child_body(child):
    """What the parent's schema reads of a child resource listed under its
    resources: the child without its template-language elements."""
    if not isinstance(child, dict):
        return child
    body = {k: v for k, v in child.items() if k not in TEMPLATE_LANGUAGE_KEYS}
    children = body.get("resources")
    if isinstance(children, list):
        body["resources"] = [child_body(c) for c in children]
    return body


class UsageError(Exception):
    """The arguments cannot be used."""


def relative_template(template):
    """Refuses TEMPLATE unless it is a path relative to the directory the check
    runs in that stays inside it: the path each finding's id carries."""
    norm = os.path.normpath(template)
    if os.path.isabs(template) or norm == os.pardir or norm.startswith(os.pardir + os.sep):
        raise UsageError(f"the template {template} is named by an absolute path or one leading out of the "
                         "directory the check runs in, and each finding's id carries the path as named: "
                         "name it relative to that directory, from inside it")


USAGE = "usage: <python> -I scripts/vendor-validate-arm.py SCHEMAS TEMPLATE...  (see the header of this file)"


def main(argv):
    if len(argv) >= 1 and argv[0] in ("-h", "--help"):
        print(USAGE)
        return 0
    if len(argv) < 2:
        print(f"{ME}: {USAGE}", file=sys.stderr)
        return 2
    prime = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vendor-validate.sh") + " --prime"
    try:
        for template in argv[1:]:
            relative_template(template)
        check = Check(Schemas(argv[0]))
        for template in argv[1:]:
            check.run(template, os.path.normpath(template))
    except UsageError as e:
        print(f"{ME}: {e}", file=sys.stderr)
        return 2
    except (NoVerdict, referencing.exceptions.Unresolvable) as e:
        print(f"✗ {ME}: no verdict — {e}. Prime the cache (network, once): {prime}", file=sys.stderr)
        return 3
    for line in check.findings:
        print(line)
    print(f"{len(check.findings)} finding(s)")
    return 1 if check.findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
