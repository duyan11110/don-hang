# lesson: backend.l3.message-broker
# The Notifications service's own image, built like the api's (see
# DonHang.Api/Dockerfile): the SDK builds, a smaller runtime image runs.
# Only the two projects it uses are copied in.
FROM mcr.microsoft.com/dotnet/sdk:10.0@sha256:de4fe90a98845d75910b9769662465c84de1a934665c431279d1382b2bddc02b AS build
WORKDIR /src

COPY global.json Directory.Packages.props Directory.Build.props ./
COPY DonHang.Messaging/DonHang.Messaging.csproj DonHang.Messaging/packages.lock.json DonHang.Messaging/
COPY DonHang.Notifications/DonHang.Notifications.csproj DonHang.Notifications/packages.lock.json DonHang.Notifications/
RUN dotnet restore DonHang.Notifications/DonHang.Notifications.csproj --locked-mode

COPY DonHang.Messaging/ DonHang.Messaging/
COPY DonHang.Notifications/ DonHang.Notifications/
RUN dotnet publish DonHang.Notifications/DonHang.Notifications.csproj -c Release -o /app --no-restore

# `--target migrate`: the migration bundle for donhang_notifications. Run
# against a database that does not exist yet, it creates it first.
FROM build AS bundle
COPY .config/dotnet-tools.json .config/
RUN dotnet tool restore \
    && dotnet ef migrations bundle --project DonHang.Notifications --configuration Release --output /bundle/efbundle

# aspnet, not runtime as for the api's bundle: this is a web project, and
# its bundle asks for the ASP.NET Core framework even though it never serves.
FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:de0ee358cdd672f7017a003bed21e9ac9ed48a27c922a59b18175b6e82fa7fee AS migrate
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /migrate
COPY --from=bundle /bundle/efbundle .
# Not root either: the same non-root user as the service's image below.
USER $APP_UID
ENTRYPOINT ["./efbundle"]

FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:de0ee358cdd672f7017a003bed21e9ac9ed48a27c922a59b18175b6e82fa7fee AS final
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
# Not root: the non-root user the .NET images include, by its number
# (see DonHang.Api/Dockerfile).
USER $APP_UID
ENTRYPOINT ["dotnet", "DonHang.Notifications.dll"]
