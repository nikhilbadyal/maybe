# SonarQube Self-Hosted Integration

This document explains the SonarQube integration setup for the Maybe project.

## Configuration Type

This project uses a **self-hosted SonarQube Server** instance (not SonarCloud).

## GitHub Secrets Required

The following secrets must be configured in your GitHub repository:

- ✅ `SONAR_TOKEN` - Authentication token for your SonarQube Server
- ✅ `SONAR_HOST_URL` - URL of your self-hosted SonarQube Server (e.g., `https://sonar.example.com`)

To verify secrets are set, run:
```bash
gh secret list -R nikhilbadyal/maybe
```

### ⚠️ Important: Secret Passing for Reusable Workflows

Since `ci.yml` is a **reusable workflow** (uses `workflow_call`), secrets MUST be explicitly passed from the calling workflows (`pr.yml` and `commit.yml`). Secrets are NOT automatically inherited!

**Configured in `ci.yml`:**
```yaml
on:
  workflow_call:
    secrets:
      SONAR_TOKEN:
        required: false
      SONAR_HOST_URL:
        required: false
```

**Passed from `pr.yml` and `commit.yml`:**
```yaml
jobs:
  ci:
    uses: ./.github/workflows/ci.yml
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
```

Without this explicit passing, you'll get errors like:
- `Expected URL scheme 'http' or 'https' but no scheme was found`
- `Failed to query JRE metadata`

## How It Works

### 1. Test Execution with Coverage
- Both `test_unit_integration` and `test_system` jobs run with `COVERAGE=true`
- SimpleCov generates coverage reports in `coverage/.resultset.json` format
- Coverage artifacts are uploaded for the SonarQube job

### 2. Linting with Rubocop
- Rubocop runs and generates a JSON report at `tmp/rubocop-results.json`
- This report is uploaded as an artifact for SonarQube analysis

### 3. SonarQube Analysis
The `sonar` job:
- Runs after all tests and linting complete
- Downloads coverage artifacts from both test jobs
- Downloads rubocop results
- Merges coverage reports
- Runs SonarQube scan using `sonarqube-scan-action@v5.0.0`
- Sends results to your self-hosted SonarQube Server

## Key Configuration Files

### `.github/workflows/ci.yml`
- Defines the CI pipeline with SonarQube integration
- Uses `SonarSource/sonarqube-scan-action@v5.0.0` (for self-hosted servers)

### `sonar-project.properties`
Key settings for self-hosted SonarQube:
```properties
sonar.projectKey=maybe
sonar.projectName=Maybe

# Sources
sonar.sources=app,lib,config

# Tests
sonar.tests=test

# Coverage
sonar.ruby.coverage.reportPaths=coverage/.resultset.json

# Rubocop
sonar.ruby.rubocop.reportPaths=tmp/rubocop-results.json
```

**Note:** `sonar.organization` is NOT used for self-hosted servers (only for SonarCloud).

## What Gets Analyzed

### Code Quality
- **Languages:** Ruby, JavaScript
- **Source Directories:** `app/`, `lib/`, `config/`
- **Test Directory:** `test/`
- **Linting:** Rubocop results for code quality issues

### Code Coverage
- Coverage from unit and integration tests
- Coverage from system tests
- Merged into a single report

### Exclusions
- `vendor/`, `node_modules/`, `tmp/`, `log/`, `coverage/`
- Database migrations (`db/migrate/`)
- Auto-generated files (`db/schema.rb`)
- Test fixtures and VCR cassettes

## Troubleshooting

### Issue: "SONAR_TOKEN is not recommended"
**Solution:** Ensure `SONAR_TOKEN` is set in GitHub Secrets (not in code).

### Issue: "Failed to query JRE metadata"
**Solution:** This means `SONAR_TOKEN` is not being passed correctly. Verify:
1. Secret is named exactly `SONAR_TOKEN`
2. Secret has a valid token from your SonarQube Server

### Issue: Cannot connect to SonarQube Server
**Solution:** Verify:
1. `SONAR_HOST_URL` is set correctly (including protocol: `https://`)
2. Your SonarQube Server is accessible from GitHub Actions runners
3. Firewall rules allow GitHub Actions IPs (if applicable)

## Running Locally

To generate coverage reports locally:
```bash
COVERAGE=true bin/rails test
```

Coverage reports will be in `coverage/.resultset.json`.

## References

- [SonarQube Scan Action Documentation](https://github.com/SonarSource/sonarqube-scan-action)
- [SonarQube Server Documentation](https://docs.sonarsource.com/sonarqube-server/)
- [SimpleCov Documentation](https://github.com/simplecov-ruby/simplecov)

