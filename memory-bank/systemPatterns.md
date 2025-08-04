# System Patterns: GPO Report Search Architecture

## Core Architecture Patterns

### Dual Processing Strategy
The system implements a **Strategy Pattern** to handle different XML formats:

```
Input XML Type Detection
    ├── PowerShell GPO XMLs → Search-GPOSettings.ps1
    └── GPMC Report XMLs → Search-GPMCReports.ps1
```

**Rationale**: Different XML formats require distinct parsing approaches due to namespace usage and structural differences.

### XML Processing Pipeline

**GPMC Report Processing (Primary Focus)**:

```
XML File Input
    ↓
Encoding Detection & Correction
    ↓
XML Document Loading
    ↓
GPO Information Extraction
    ↓
Node Collection & Search
    ↓
Category Path Resolution
    ↓
Result Compilation & Deduplication
    ↓
Structured Output
```

**Key Design Decisions**:
- **Encoding Resilience**: Auto-detect and fix UTF-16/UTF-8 mismatches
- **Namespace Awareness**: Handle Microsoft Group Policy namespaces properly
- **Lazy Loading**: Process files only when needed for performance
- **Fail-Safe Processing**: Continue on individual file errors

### Category Detection Architecture

**Hierarchical Category Resolution**:

```
XML Node Match
    ↓
Context Analysis (Parent/Ancestor Traversal)
    ↓
Namespace Detection
    ├── Security Extension → Get-SecuritySubcategory()
    ├── Administrative Templates → Standard Path Building
    ├── Advanced Audit → Get-AuditSubcategory()
    └── Group Policy Preferences → Standard Categorization
    ↓
Category Path Construction
```

**Critical Patterns**:
- **Namespace-Driven Routing**: Different processing based on XML namespace
- **Context-Aware Categorization**: Use parent/ancestor elements for accurate paths
- **Fallback Hierarchy**: Multiple detection methods with graceful degradation

## Component Relationships

### Function Architecture

**Search-GPMCReports.ps1 Core Functions**:

```
Main Script Entry Point
├── ConvertTo-RegexPattern (Utility)
├── Get-GPMCGpoInfo (Data Extraction)
├── Get-GPMCCategoryPath (Primary Categorization)
│   ├── Get-SecuritySubcategory (Security-Specific)
│   └── Get-AuditSubcategory (Audit-Specific)
└── Result Processing & Output
```

**Function Responsibilities**:
- **ConvertTo-RegexPattern**: Wildcard to regex conversion with case handling
- **Get-GPMCGpoInfo**: Extract GPO metadata (name, domain, GUID, timestamps)
- **Get-GPMCCategoryPath**: Main category detection orchestrator
- **Get-SecuritySubcategory**: Handle Security Settings namespace complexity
- **Get-AuditSubcategory**: Distinguish audit policy types

### Data Flow Patterns

**Search Process Flow**:

```
User Input (Path + SearchString)
    ↓
File Discovery (Single/Directory/Recursive)
    ↓
Per-File Processing Loop
    ├── XML Loading with Error Handling
    ├── GPO Context Extraction
    ├── Node Search (Text + Attributes)
    ├── Match Processing
    │   ├── Category Path Resolution
    │   ├── Context Extraction
    │   └── Duplicate Detection
    └── Result Accumulation
    ↓
Final Result Compilation
    ↓
Output Generation
```

## Critical Implementation Paths

### Security Settings Processing

**Complex Namespace Handling**:

```xml
<Extension xmlns:q1="http://www.microsoft.com/GroupPolicy/Settings/Security">
    <q1:Account>
        <q1:Type>Password</q1:Type>
        <q1:Name>PasswordHistorySize</q1:Name>
    </q1:Account>
</Extension>
```

**Processing Logic**:
1. Detect Security namespace (`http://www.microsoft.com/GroupPolicy/Settings/Security`)
2. Identify element type (`Account`, `LocalPolicies`, `AuditPolicies`)
3. Extract subcategory from `Type` element
4. Construct appropriate category path

### Advanced Audit Configuration

**Specialized Detection Pattern**:

```xml
<q1:AuditSetting>
    <q1:SubCategoryGuid>{guid}</q1:SubCategoryGuid>
    <q1:SubCategoryName>Audit Kerberos Service Ticket Operations</q1:SubCategoryName>
</q1:AuditSetting>
```

**Categorization Logic**:
1. Detect `AuditSetting` with `SubCategoryName`
2. Map to "Security Settings > Advanced Audit Configuration"
3. Determine subcategory based on audit type patterns

### Administrative Templates

**Hierarchy Path Construction**:

```xml
<q2:Policy>
    <q2:Name>Turn off notifications network usage</q2:Name>
    <q2:Category>Start Menu and Taskbar/Notifications</q2:Category>
</q2:Policy>
```

**Path Building**:
1. Extract category from `Category` element
2. Split on '/' delimiter
3. Prepend "Administrative Templates"
4. Construct full hierarchy path

## Quality Assurance Patterns

### Testing Strategy

**Validation Approach**:
- **Mapping Table Validation**: Automated Pester tests against known patterns
- **Real-World XML Testing**: Process diverse XML files from actual environments
- **Edge Case Coverage**: Handle encoding issues, malformed XML, missing elements
- **Regression Prevention**: Comprehensive test suite prevents breaking changes

### Error Handling Strategy

**Resilient Processing**:
- **Continue on Error**: Individual file failures don't stop batch processing
- **Encoding Recovery**: Auto-detect and fix common encoding mismatches
- **Graceful Degradation**: Return partial information when full parsing fails
- **Verbose Logging**: Detailed diagnostic information for troubleshooting

## Performance Considerations

### Optimization Patterns

**Memory Management**:
- **Stream Processing**: Don't load all files into memory simultaneously
- **Selective Parsing**: Parse only required XML elements
- **Result Buffering**: Accumulate results efficiently

**Search Optimization**:
- **Early Termination**: Stop search when MaxResults reached
- **Pattern Compilation**: Pre-compile regex patterns for reuse
- **Duplicate Prevention**: Filter duplicates during processing, not post-processing

## Extension Points

### Pluggable Category Detection
The category detection system is designed for extensibility:

```powershell
# Future category detectors can be added:
# - Get-PreferencesSubcategory for GP Preferences
# - Get-RegistrySubcategory for Registry-specific detection
# - Get-SoftwareSubcategory for Software Installation
```

### Output Format Extensions
Current object-based output enables future enhancements:
- JSON export capability
- CSV formatting
- HTML report generation
- Integration with external systems
