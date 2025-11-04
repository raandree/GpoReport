# GpoReport Examples and Demonstrations

This directory contains demonstration scripts and test validation tools that showcase the capabilities of the GpoReport PowerShell module.

## 📁 Directory Structure

```
examples/
├── README.md                           # This file
├── Demo-GPOEnhancements.ps1           # Comprehensive feature demonstrations
├── Demo-XMLNodeContext.ps1            # XML node context feature demo
├── Demo-EnhancedXMLContext.ps1        # Enhanced XML context improvements
└── Demo-ShowGPOSearchReportUi.ps1     # GUI demo for GPO search report generator
```

## 🚀 Demo Scripts

### Demo-GPOEnhancements.ps1
**Purpose**: Comprehensive demonstration of all enhanced GPO search capabilities  
**Features Demonstrated**:
- Multi-format export capabilities (JSON, CSV, HTML, XML)
- Compliance analysis with security frameworks
- Interactive GUI interface for GPO searching
- Performance optimization features
- GPO insights and analysis tools
- High-performance cached search functionality

**Usage**:
```powershell
.\examples\Demo-GPOEnhancements.ps1
```

### Demo-XMLNodeContext.ps1
**Purpose**: Demonstrates the enhanced XML node context feature  
**Features Demonstrated**:
- Enhanced XML node property structure
- Meaningful parent element detection
- Complete policy block capture
- Parent hierarchy tracking
- Context-aware XML processing

**Usage**:
```powershell
.\examples\Demo-XMLNodeContext.ps1
```

### Demo-EnhancedXMLContext.ps1
**Purpose**: Showcases improvements in XML node context capture  
**Features Demonstrated**:
- Policy-level context capture vs element-level context
- Enhanced OuterXml content inclusion
- Meaningful parent detection improvements
- Context hierarchy understanding

**Usage**:
```powershell
.\examples\Demo-EnhancedXMLContext.ps1
```

### Demo-ShowGPOSearchReportUi.ps1
**Purpose**: Interactive demonstration of the GUI for generating GPO search reports  
**Features Demonstrated**:
- User-friendly graphical interface
- Two search modes: Local XML files and Active Directory queries
- Guided input fields with validation
- Browse dialogs for file and folder selection
- Automatic HTML report generation
- Progress indicators and status feedback

**Usage**:
```powershell
.\examples\Demo-ShowGPOSearchReportUi.ps1
```

## 🧪 Test Scripts

Test scripts have been moved to the `.\tests\` folder at the repository root.

See `.\tests\` for:
- `Test-XMLNodeContextFeature.ps1` - XML node context feature validation
- `Test-GpoFilterParameter.ps1` - GPO filter parameter validation
- `Test-ShowGPOSearchReportUi.ps1` - UI launcher test script

**Usage**:
```powershell
.\tests\Test-XMLNodeContextFeature.ps1
.\tests\Test-GpoFilterParameter.ps1
```

## 📋 Prerequisites

Before running these scripts, ensure:

1. **Module Built**: Run `.\build.ps1` to build the GpoReport module
2. **Test Data Available**: Ensure `.\tests/TestData\AllSettings1.xml` exists
3. **PowerShell Execution Policy**: Set to allow script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## 🎯 Quick Start

To run all demonstrations:

```powershell
# Build the module first
.\build.ps1

# Run comprehensive feature demo
.\examples\Demo-GPOEnhancements.ps1

# Launch the GPO Search Report UI demo
.\examples\Demo-ShowGPOSearchReportUi.ps1

# Test XML context features
.\tests\Test-XMLNodeContextFeature.ps1

# Explore XML node context capabilities
.\examples\Demo-XMLNodeContext.ps1
```

## 📊 Expected Outputs

### Demo Scripts
- **Console Output**: Colorized demonstrations with step-by-step feature showcases
- **Export Files**: Generated in `.\output\` directory (JSON, CSV, HTML, XML formats)
- **GUI Windows**: Interactive search interfaces (where applicable)

### Test Scripts
- **Validation Results**: Pass/fail status for each test with detailed feedback
- **Feature Verification**: Confirmation that all enhanced features work correctly
- **Performance Metrics**: Timing and efficiency measurements

## 🔧 Troubleshooting

**Common Issues**:

1. **Module Import Errors**: Ensure the module is built first with `.\build.ps1`
2. **Missing Test Data**: Verify `.\tests/TestData\AllSettings1.xml` exists
3. **Path Issues**: Run scripts from the repository root directory
4. **Execution Policy**: Ensure PowerShell allows script execution

**Getting Help**:
- Check the main project README.md for setup instructions
- Review the docs/ folder for detailed documentation
- Examine the source code for specific function implementations

## 📚 Related Documentation

- **Main Documentation**: See `.\docs\` folder for comprehensive guides
- **API Reference**: Check function help with `Get-Help <FunctionName> -Full`
- **Development Notes**: Review `.\memory-bank\` for technical details
- **Testing Framework**: See `.\tests\` for unit and integration tests

---

*These examples showcase the full capabilities of the GpoReport module, demonstrating both basic usage and advanced features for GPO analysis and reporting.*
