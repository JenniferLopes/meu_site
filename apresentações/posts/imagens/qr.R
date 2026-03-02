# Instalar pacotes necessários (se ainda não tiver)
# install.packages("qrcode")
# install.packages("png")
# install.packages("grid")

library(qrcode)
library(png)
library(grid)

# ============================================================
# CONFIGURAÇÕES - edite aqui
# ============================================================
url        <- "https://jenniferlopes.quarto.pub/portifolio/apresenta%C3%A7%C3%B5es/"
logo_path  <- "logo.png"   # ← coloque aqui o caminho do seu arquivo
output     <- "qrcode_com_logo.png"
tamanho_logo <- 0.25       # tamanho do logo em relação ao QR (0.25 = 25%)
# ============================================================

# Gerar QR Code
qr <- qr_code(url, ecl = "H")  # ecl = "H" permite até 30% de sobreposição

# Abrir o logo
logo <- readPNG(logo_path)

# Salvar PNG com logo sobreposto
png(output, width = 600, height = 600, res = 150)

# Plotar QR code
plot(qr)

# Calcular posição central para o logo
vp <- viewport(
  x      = 0.5,
  y      = 0.5,
  width  = tamanho_logo,
  height = tamanho_logo
)

# Sobrepor o logo
pushViewport(vp)
grid.raster(logo)
popViewport()

dev.off()

cat("✅ QR Code com logo salvo como '", output, "'\n", sep = "")