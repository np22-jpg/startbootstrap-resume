FROM quay.io/almalinuxorg/9-base AS installer

RUN dnf module --assumeyes enable nodejs:18
RUN dnf install --assumeyes --setopt=install_weak_deps=false --nodocs \
  git jq npm wget

RUN npm install -g npm@$(curl "https://release-monitoring.org/api/v2/versions/?project_id=190206" | jq --raw-output '.stable_versions[0]')

FROM installer AS packprovider
COPY --from=quay.io/almalinuxorg/9-micro / /rpms

RUN dnf module --assumeyes enable \
  --installroot /rpms \
  --releasever=9 \
  nodejs:18

RUN dnf install --assumeyes --setopt=install_weak_deps=false --nodocs \
  --installroot /rpms \
  --releasever=9 \
  nginx-core ca-certificates

RUN dnf clean all \
  --installroot /rpms

FROM installer AS gitprovider
RUN mkdir /app
WORKDIR /app

COPY package.json ./
RUN npm update

COPY ./ ./
RUN npm run build


FROM quay.io/almalinuxorg/9-micro  AS release
COPY --from=packprovider /rpms /
COPY --from=gitprovider /app/dist /usr/share/nginx/html

# EXPOSE 80/tcp
ENTRYPOINT [ "nginx", "-g", "daemon off;" ]