# ─────────────────────────────────────────────────────────────
# Multi-stage Dockerfile for the OrderManager monolith.
# Three stages keep the final image small (~100 MB) by
# discarding Node and .NET SDK tooling after compilation.
# ─────────────────────────────────────────────────────────────

# Stage 1: Build the Angular 17 SPA
# Produces static assets in dist/client-app/browser/ that will
# be embedded into the .NET API's wwwroot directory in Stage 2.
FROM node:20-alpine AS client-build
WORKDIR /app/client
COPY client-app/package*.json ./
RUN npm ci                          # deterministic install from lockfile
COPY client-app/ ./
RUN npm run build                   # Angular AOT build → dist/

# Stage 2: Build the .NET 8 API
# Restores NuGet packages first (layer cache), then copies full
# source + Angular output and publishes a self-contained Release build.
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS api-build
WORKDIR /src
COPY OrderManager.sln ./
COPY src/OrderManager.Api/OrderManager.Api.csproj src/OrderManager.Api/
COPY tests/OrderManager.Api.Tests/OrderManager.Api.Tests.csproj tests/OrderManager.Api.Tests/
RUN dotnet restore                  # cached layer for NuGet packages
COPY . .
# Embed the Angular SPA into wwwroot so a single binary serves both API and UI
COPY --from=client-build /app/client/dist/client-app/browser src/OrderManager.Api/wwwroot/
RUN dotnet publish src/OrderManager.Api/OrderManager.Api.csproj -c Release -o /app/publish

# Stage 3: Minimal runtime image (Alpine-based, no SDK)
# Only the published output is copied—no source code or build tools.
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app
COPY --from=api-build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "OrderManager.Api.dll"]
