# ==============================================================================
# Multi-stage Dockerfile for the OrderManager .NET + Angular monolith.
# This build process compiles both the Angular frontend and .NET backend,
# then packages them into a minimal Alpine-based runtime image. The multi-stage
# approach keeps the final image small by excluding build tools and source code.
#
# Build context: The root of the app_dotnet-angular-monolith repository.
# The CI pipeline checks out the app repo and references this Dockerfile
# from the IaC repo using: docker build -f ../iac/docker/Dockerfile .
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build the Angular frontend (client-app).
# Uses Node.js 20 Alpine for a lightweight build environment. The Angular CLI
# compiles TypeScript into optimized static assets (HTML, CSS, JS) that will
# be served by the .NET backend from its wwwroot directory.
# ------------------------------------------------------------------------------
FROM node:20-alpine AS client-build
WORKDIR /app/client
# Copy package manifests first to leverage Docker layer caching.
# npm ci will only re-run if package.json or package-lock.json change,
# saving time on rebuilds when only source code changes.
COPY client-app/package*.json ./
# npm ci (clean install) ensures reproducible builds by installing exact
# versions from package-lock.json, unlike npm install which may resolve
# different versions.
RUN npm ci
# Copy the full Angular source code and build for production.
COPY client-app/ ./
RUN npm run build

# ------------------------------------------------------------------------------
# Stage 2: Build the .NET API backend.
# Uses the official .NET 8 SDK image which includes the compiler, NuGet,
# and all build tools. The SDK image is large (~900MB) but is only used
# during the build stage and excluded from the final runtime image.
# ------------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS api-build
WORKDIR /src
# Copy solution and project files first for dependency caching.
# dotnet restore only re-runs if .csproj or .sln files change.
COPY OrderManager.sln ./
COPY src/OrderManager.Api/OrderManager.Api.csproj src/OrderManager.Api/
COPY tests/OrderManager.Api.Tests/OrderManager.Api.Tests.csproj tests/OrderManager.Api.Tests/
# Restore NuGet packages as a separate layer for caching efficiency.
RUN dotnet restore
# Copy all remaining source code after restore to maximize cache hits.
COPY . .
# Copy the compiled Angular assets from Stage 1 into the .NET project's
# wwwroot directory. The .NET app serves these static files directly,
# so both frontend and backend are served from a single container.
COPY --from=client-build /app/client/dist/client-app/browser src/OrderManager.Api/wwwroot/
# Publish a Release build to /app/publish. This creates a self-contained
# deployment with optimized assemblies ready for the runtime image.
RUN dotnet publish src/OrderManager.Api/OrderManager.Api.csproj -c Release -o /app/publish

# ------------------------------------------------------------------------------
# Stage 3: Runtime — the final, minimal production image.
# Uses the ASP.NET 8 Alpine runtime image (~100MB) which includes only the
# .NET runtime (no SDK/compiler). Alpine Linux minimizes the attack surface
# and image size compared to Debian-based alternatives.
# ------------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app
# Copy only the published application artifacts from Stage 2.
# No source code, build tools, or intermediate files are included.
COPY --from=api-build /app/publish .
# Expose port 8080 for HTTP traffic. This is the port Kubernetes
# health probes and the Service target (matching values.yaml targetPort).
EXPOSE 8080
# Configure the .NET app to listen on all interfaces at port 8080.
# This is required for Kubernetes — the app must bind to 0.0.0.0,
# not just localhost, to receive traffic from the Service/Ingress.
ENV ASPNETCORE_URLS=http://+:8080
# Use the dotnet CLI as the entrypoint to run the compiled application DLL.
ENTRYPOINT ["dotnet", "OrderManager.Api.dll"]
