# lesson: devops.l1.dockerfile-for-dotnet
# lesson: devops.l1.multi-stage-builds
# Stage 1 has the SDK and builds the app; stage 2 only copies the result into
# a smaller runtime image. The final image never contains the SDK or source.
# lesson: devops.l3.pinning-by-content
# From stage-3 every base image is named by tag and digest: the digest decides
# what is pulled, the tag only says which line it came from. Each project's
# packages.lock.json comes in with its .csproj, and --locked-mode makes the
# restore fail instead of choosing a version the lock file does not name.
FROM mcr.microsoft.com/dotnet/sdk:10.0@sha256:de4fe90a98845d75910b9769662465c84de1a934665c431279d1382b2bddc02b AS build
WORKDIR /src

COPY global.json Directory.Packages.props Directory.Build.props ./
COPY DonHang.Catalog/DonHang.Catalog.csproj DonHang.Catalog/packages.lock.json DonHang.Catalog/
COPY DonHang.Domain/DonHang.Domain.csproj DonHang.Domain/packages.lock.json DonHang.Domain/
COPY DonHang.Infrastructure/DonHang.Infrastructure.csproj DonHang.Infrastructure/packages.lock.json DonHang.Infrastructure/
COPY DonHang.Messaging/DonHang.Messaging.csproj DonHang.Messaging/packages.lock.json DonHang.Messaging/
COPY DonHang.Api/DonHang.Api.csproj DonHang.Api/packages.lock.json DonHang.Api/
RUN dotnet restore DonHang.Api/DonHang.Api.csproj --locked-mode

COPY DonHang.Catalog/ DonHang.Catalog/
COPY DonHang.Domain/ DonHang.Domain/
COPY DonHang.Infrastructure/ DonHang.Infrastructure/
COPY DonHang.Messaging/ DonHang.Messaging/
COPY DonHang.Api/ DonHang.Api/
RUN dotnet publish DonHang.Api/DonHang.Api.csproj -c Release -o /app --no-restore

# lesson: devops.l2.migrations-in-the-pipeline
# `docker build --target migrate` stops here instead: an image holding only a
# migration bundle, one executable that applies the migrations a database has
# not recorded as applied yet. It is built from the same source as the api.
FROM build AS bundle
COPY .config/dotnet-tools.json .config/
RUN dotnet tool restore \
    && dotnet ef migrations bundle --project DonHang.Infrastructure --configuration Release --output /bundle/efbundle

FROM mcr.microsoft.com/dotnet/runtime:10.0@sha256:a3f9f81954b9c810af2ed18849716c8dc74a4707bd0907fdbd69be81554c0f30 AS migrate
# The same Kerberos library as the api image below, for the same reason.
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /migrate
COPY --from=bundle /bundle/efbundle .
# Not root either: the same non-root user as the image below.
USER $APP_UID
ENTRYPOINT ["./efbundle"]

# The api's image: the default target, because it is the last stage.
FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:de0ee358cdd672f7017a003bed21e9ac9ed48a27c922a59b18175b6e82fa7fee AS final
WORKDIR /app
# Npgsql probes for Kerberos/GSSAPI support at startup; without this library
# present that probe logs a scary but harmless "cannot open shared object" line.
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
# lesson: k8s.l3.security-context
# From stage-3 the api runs as the non-root user the .NET images include. By
# its number, APP_UID, not its name: Kubernetes' runAsNonRoot can check only
# a number. Without this line the process runs as root.
USER $APP_UID
ENTRYPOINT ["dotnet", "DonHang.Api.dll"]
