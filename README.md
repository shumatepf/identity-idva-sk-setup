# IDVA SK Deployment Setup
This action performs the deployment steps common to all SK microservices
within IDVA.

# Usage
```yaml
- uses: 18F/identity-idva-sk-setup@v1
  with:
    require-redis: "true" # Each 'require-<x>' parameter is optional
    require-postgres: "true"
    require-elasticsearch: "true" 
    s3-url: <s3://myurl.aws.com>
    app-directory: sk-<directory>
    sk-secrets: ${{ secrets[env.SK_SECRETS] }}
```
