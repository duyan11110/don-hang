# lesson: devops.l1.dockerfile-for-dotnet
# lesson: devops.l1.multi-stage-builds
# Stage 1 has the SDK and builds the app; stage 2 only copies the result into
# a smaller runtime image. The final image never contains the SDK or source.
# lesson: devops.l3.pinning-by-content
# From stage-3 every base image is named by tag and digest: the digest decides
# what is pulled, the tag only says which line it came from. Each project's
# packages.lock.json comes in with its .csproj, and --locked-mode makes the
# restore fail instead of choosing a version the lock file does not name.
FROM mcr.microsoft.com/dotnet/sdk:10.0@sha256:e70cdb7f80b0348f5cb85f19a8f670fca061f033d57eed12fa003d58b0e06317 AS build
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

FROM mcr.microsoft.com/dotnet/runtime:10.0@sha256:b89586dc17781f25531909993658aa8161205ae38b8cec8847df4a8221a403d5 AS migrate
# The same Kerberos library as the api image below, for the same reason.
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /migrate
COPY --from=bundle /bundle/efbundle .
ENTRYPOINT ["./efbundle"]

# The api's image: the default target, because it is the last stage.
FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:222759b391a1aaf241166672c8f99b2d4ada452e7b5319f3c6e8f265a37b5ad4 AS final
WORKDIR /app
# Npgsql probes for Kerberos/GSSAPI support at startup; without this library
# present that probe logs a scary but harmless "cannot open shared object" line.
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "DonHang.Api.dll"]
