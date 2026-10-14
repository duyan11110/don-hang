# The fake payment gateway's image: one small project, no other code copied in.
FROM mcr.microsoft.com/dotnet/sdk:10.0@sha256:0d99ebf1ccad15037b5c98c9fe8979d6b8dbac23812feae2277a0b277b5c5ffa AS build
WORKDIR /src
COPY global.json Directory.Packages.props Directory.Build.props ./
COPY fake-gateway/FakeGateway.csproj fake-gateway/packages.lock.json fake-gateway/
RUN dotnet restore fake-gateway/FakeGateway.csproj --locked-mode
COPY fake-gateway/ fake-gateway/
RUN dotnet publish fake-gateway/FakeGateway.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:222759b391a1aaf241166672c8f99b2d4ada452e7b5319f3c6e8f265a37b5ad4 AS final
WORKDIR /app
COPY --from=build /app .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
# Not root: the non-root user the .NET images include, by its number
# (see DonHang.Api/Dockerfile).
USER $APP_UID
ENTRYPOINT ["dotnet", "FakeGateway.dll"]
