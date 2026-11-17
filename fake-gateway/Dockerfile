# The fake payment gateway's image: one small project, no other code copied in.
FROM mcr.microsoft.com/dotnet/sdk:11.0@sha256:65f3c7c6a25a239ab3e6719f2896147e7b68242ff2d8818dd70498bde6ef8bea AS build
WORKDIR /src
COPY global.json Directory.Packages.props Directory.Build.props ./
COPY fake-gateway/FakeGateway.csproj fake-gateway/packages.lock.json fake-gateway/
RUN dotnet restore fake-gateway/FakeGateway.csproj --locked-mode
COPY fake-gateway/ fake-gateway/
RUN dotnet publish fake-gateway/FakeGateway.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:1a48394b6f29d3a32c79d9edecd4abda0ecbe8776d567dbfc4590ed6979c740c AS final
WORKDIR /app
COPY --from=build /app .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
# Not root: the non-root user the .NET images include, by its number
# (see DonHang.Api/Dockerfile).
USER $APP_UID
ENTRYPOINT ["dotnet", "FakeGateway.dll"]
