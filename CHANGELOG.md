# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial version of GpoReport module
- Restructured project using Sampler framework
- Added comprehensive GPO search and analysis functionality
- Implemented caching system for improved performance (`Search-GPOCached`)
- Added compliance checking and risk assessment features (`Search-GPOCompliance`)
- Added export functionality for various formats: CSV, JSON, XML, HTML (`Export-SearchResults`)
- Added AI-powered insights and analysis (`Get-GPOInsights`)
- Added `Show-GPOSearchReportUi` GUI for HTML report generation with dual search modes
  (local XML files or Active Directory queries)
- Added `Show-GPOSearchReport` for command-line HTML report generation
- Added `ConvertFrom-XmlToObject` for XML-to-PowerShell object conversion with dot notation
  access via the `ParsedXml` property on search results
- Added XML node context (`XmlNode` property) on search results with element name, parent
  hierarchy, attributes, and parsed XML data
- Added comprehensive Group Policy Preferences CategoryPath mapping for all 11 preference
  categories (Drive Maps, Environment Variables, Files, Folders, Registry, Shortcuts,
  Folder Options, Power Options, Scheduled Tasks, Start Menu, Local Users and Groups)
- Added hierarchical deduplication (`Remove-HierarchicalDuplicates`) to eliminate parent-child
  duplicate matches while preserving distinct results
- Added `IncludeChildDuplicates` parameter to bypass deduplication when needed
- Added `ReadTime` and `IncludeComments` properties to GPO metadata (`Get-GPMCGpoInfo`)
- Added dedicated RestrictedGroups rendering in HTML reports showing group name, members,
  and member-of context

### Changed

- Changed `Show-GPOSearchReportUi` search string field from a plain TextBox to a ComboBox
  (combined dropdown/text field) with auto-complete, populated with existing GPO display names
  from Active Directory when the GroupPolicy module is available
- Migrated from standalone scripts to proper PowerShell module structure
- Organized functions into Public and Private directories following Sampler conventions
- Improved error handling and logging throughout the module
- Removed `Start-GPOSearchGUI` function (replaced by `Show-GPOSearchReportUi`)
- Moved demo scripts to `examples/` folder and test scripts to `tests/` folder

### Fixed

- Resolved dependency management issues
- Fixed module building and testing pipeline
- Fixed deduplication over-collapsing when multiple XML elements share the same element name
  and category path (e.g., multiple RestrictedGroups entries) by including OuterXml hash in
  the Phase 1 dedup group key
- Fixed OuterXml truncation at 1000 characters that prevented proper parent-child relationship
  detection in deduplication
- Fixed HTML report missing restricted group name context for RestrictedGroups search results

## [0.1.0] - 2024-01-01

### Added
- Initial release with basic GPO reporting functionality
