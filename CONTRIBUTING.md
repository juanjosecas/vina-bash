# Contributing to vina-bash

Thank you for considering contributing to vina-bash! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Your environment (OS, bash version, Vina version, OpenBabel version)
- Relevant log output

### Suggesting Enhancements

We welcome suggestions for new features or improvements! Please create an issue with:
- Clear description of the proposed feature
- Use case and benefits
- Possible implementation approach (if you have ideas)

### Pull Requests

We love pull requests! Here's the process:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes** following our coding standards (see below)
4. **Test your changes** thoroughly
5. **Commit your changes** (`git commit -m 'Add amazing feature'`)
6. **Push to your branch** (`git push origin feature/amazing-feature`)
7. **Open a Pull Request**

## Coding Standards

### Bash Script Guidelines

1. **Shebang**: Always use `#!/bin/bash`

2. **Error Handling**: Use the utilities from `utils.sh`
   ```bash
   source "${SCRIPT_DIR}/utils.sh" || exit 1
   error_exit "Something went wrong"
   ```

3. **Functions**: Document all functions with comments
   ```bash
   #######################################
   # Brief description
   # Arguments:
   #   Argument descriptions
   # Returns:
   #   Return value description
   #######################################
   function_name() {
       local param1=$1
       # implementation
   }
   ```

4. **Variables**: Use descriptive names and local variables
   ```bash
   local input_file=$1
   local output_dir="results"
   ```

5. **Quoting**: Always quote variables to handle spaces
   ```bash
   if [ -f "$file" ]; then
       echo "Processing $file"
   fi
   ```

6. **Error Checking**: Check return values
   ```bash
   if ! command_that_might_fail; then
       error_exit "Command failed"
   fi
   ```

7. **Help Messages**: All scripts should have `--help` flag
   ```bash
   show_help() {
       cat << EOF
   Usage: $0 [OPTIONS]
   ...
   EOF
   }
   ```

### Code Style

- Use 4-space indentation (not tabs)
- Keep lines under 100 characters when possible
- Add blank lines between logical sections
- Use meaningful variable names (no single letters except loop counters)
- Comment complex logic
- Keep functions focused on a single task

### Testing

Before submitting a PR:

1. **Test all use cases**:
   ```bash
   ./your_script.sh --help
   ./your_script.sh  # with defaults
   ./your_script.sh --option value  # with options
   ```

2. **Test error conditions**:
   - Missing dependencies
   - Invalid input files
   - Invalid arguments

3. **Check for regressions**: Ensure existing functionality still works

4. **Test on clean environment**: Make sure all dependencies are documented

### Documentation

- Update README.md if adding new features
- Update QUICKSTART.md if changing basic workflows
- Update CHANGELOG.md with your changes
- Add inline comments for complex logic
- Update help messages for new options

## Project Structure

```
vina-bash/
├── utils.sh              # Core utilities - DO NOT BREAK
├── vina.sh              # Main docking script
├── score.sh             # Post-processing script
├── vina_pipeline.sh     # Complete workflow
├── filter_results.sh    # Result filtering
├── generate_summary.sh  # Summary reports
├── convert_format.sh    # Format conversion
├── config.txt.example   # Example config
├── README.md            # Main documentation
├── QUICKSTART.md        # Quick start guide
├── CHANGELOG.md         # Version history
└── CONTRIBUTING.md      # This file
```

### Key Components

1. **utils.sh**: Core library - changes here affect all scripts
2. **Main scripts**: Should source utils.sh and follow its patterns
3. **Documentation**: Must be kept in sync with code

## Development Workflow

1. **Always work on a feature branch**
2. **Test thoroughly before committing**
3. **Write meaningful commit messages**
   - Use present tense ("Add feature" not "Added feature")
   - Be specific about what changed
   - Reference issue numbers if applicable

4. **Keep commits focused**
   - One logical change per commit
   - Don't mix formatting changes with feature changes

## Utility Functions

When adding new utilities to `utils.sh`:

1. Follow the existing pattern
2. Document thoroughly
3. Make them reusable
4. Test independently
5. Update all scripts that could benefit

Example:
```bash
#######################################
# Check if file is valid PDBQT format
# Arguments:
#   File path
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_pdbqt() {
    local file=$1
    # implementation
}
```

## Common Patterns

### Command-line Parsing

```bash
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--option)
                OPTION="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
}
```

### Progress Tracking

```bash
for item in $items; do
    current=$((current + 1))
    show_progress "$current" "$total" "Processing"
    # process item
done
```

### File Processing

```bash
for file in $pattern; do
    if [ -f "$file" ]; then
        process_file "$file"
    fi
done
```

## Adding New Scripts

When adding a new script:

1. **Source utils.sh**
2. **Add help message with `--help` flag**
3. **Parse command-line arguments**
4. **Validate inputs**
5. **Use logging functions**
6. **Add progress tracking for long operations**
7. **Make it executable**: `chmod +x script.sh`
8. **Update README.md**
9. **Add to CHANGELOG.md**

## Questions?

Feel free to:
- Open an issue for questions
- Start a discussion
- Contact the maintainers

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Keep discussions on topic

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

## Recognition

Contributors will be acknowledged in:
- Git commit history
- Release notes
- Project documentation (for significant contributions)

Thank you for contributing to vina-bash! 🎉
