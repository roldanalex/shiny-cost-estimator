# Deployment Guide for Software Cost Estimator

## 📦 Deployment Options

### Option 1: shinyapps.io (Recommended for Free Hosting)

**Steps:**

1. **Create Account**
   - Visit [shinyapps.io](https://www.shinyapps.io/)
   - Sign up for free account (5 apps, 25 active hours/month)

2. **Install rsconnect**
   ```r
   install.packages("rsconnect")
   ```

3. **Configure Credentials**
   - Go to shinyapps.io → Account → Tokens
   - Click "Show" and copy your token
   - Run in R:
   ```r
   rsconnect::setAccountInfo(
     name = 'your-account-name',
     token = 'your-token-here',
     secret = 'your-secret-here'
   )
   ```

4. **Deploy** — always use the deploy script, which re-syncs the engine
   copies in `modules/` before bundling:
   ```bash
   # From project root
   Rscript tools/deploy.R
   ```
   (It runs `tools/sync_modules.R` and then
   `rsconnect::deployApp(appDir = 'cost-estimator-app', appName = 'shiny-cost-estimator', forceUpdate = TRUE)`.)

5. **Smoke-test the PDF report** — after your first deploy, run a Manual
   Entry analysis on the live site and click **Download PDF Report**. See
   the "PDF Reports (Quarto + Typst)" section below if it fails.

6. **Configure Settings** (on shinyapps.io dashboard)
   - Instance size: Small (1GB RAM sufficient)
   - Max worker processes: 1
   - Max connections: 50

**Free Tier Limits:**
- ✅ 5 applications
- ✅ 25 active hours/month
- ✅ 1GB RAM per instance
- ⚠️ Apps sleep after 15 min inactivity

---

### PDF Reports (Quarto + Typst) on shinyapps.io

The branded PDF report renders with **Quarto + Typst** — deliberately chosen
because shinyapps.io has **no Chrome and no LaTeX**. Typst ships inside the
Quarto CLI (>= 1.3), so nothing extra needs installing.

How the pieces are wired:

- `app.R` calls `requireNamespace("quarto")` / `"ragg"` / `"knitr"` at the top
  so rsconnect's dependency scanner bundles those R packages (they are only
  used from `report/estimate_report.qmd`, which the scanner does not parse).
- shinyapps.io provisions the Quarto CLI when the `quarto` R package is in the
  bundle. At runtime the app checks `quarto::quarto_path()` and shows a clear
  message instead of the download button if the CLI is missing.
- Rendering happens in a copy of `report/` under `tempdir()` because the
  deployed app directory is not reliably writable.
- Source Sans 3 and Source Serif 4 are bundled in `report/fonts/` (`font-paths` in the qmd) because
  Google Fonts cannot be fetched at render time server-side.
- First render takes ~5-15 s; a progress bar covers it.

If the PDF button reports Quarto missing on shinyapps.io: redeploy with
rsconnect >= 1.0 and confirm `quarto` appears in the app's package list on the
dashboard.

---

### Option 2: RStudio Connect (Enterprise)

**Steps:**

1. **Install RStudio Connect** (on server)
   ```bash
   # Ubuntu example
   sudo gdebi rstudio-connect-*.deb
   ```

2. **Configure rsconnect**
   ```r
   rsconnect::addServer(
     url = "https://your-connect-server.com",
     name = "company-connect"
   )
   ```

3. **Deploy**
   ```r
   rsconnect::deployApp(
     appDir = 'cost-estimator-app',
     server = 'company-connect',
     account = 'your-username'
   )
   ```

**Benefits:**
- ✅ No usage limits
- ✅ Full control
- ✅ Authentication integration
- ✅ SSL certificates
- ⚠️ Requires license (~$10K-30K/year)

---

### Option 3: Shiny Server (Open Source)

**Steps:**

1. **Install Shiny Server**
   ```bash
   # Ubuntu
   sudo apt-get install gdebi-core
   wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.20.1002-amd64.deb
   sudo gdebi shiny-server-1.5.20.1002-amd64.deb
   ```

2. **Copy App to Server**
   ```bash
   sudo cp -R cost-estimator-app /srv/shiny-server/
   ```

3. **Install Dependencies**
   ```r
   # As shiny user
   sudo su - shiny
   R
   install.packages(c("shiny", "bslib", "plotly", "DT", "shinyWidgets", "jsonlite", "RColorBrewer"))
   ```

4. **Configure** `/etc/shiny-server/shiny-server.conf`:
   ```
   run_as shiny;
   server {
     listen 3838;
     location /cost-estimator {
       site_dir /srv/shiny-server/cost-estimator-app;
       log_dir /var/log/shiny-server;
       directory_index on;
     }
   }
   ```

5. **Restart Server**
   ```bash
   sudo systemctl restart shiny-server
   ```

**Access**: `http://your-server:3838/cost-estimator`

---

### Option 4: Docker Container

**Steps:**

1. **Create Dockerfile** (in `cost-estimator-app/`)
   ```dockerfile
   FROM rocker/shiny:4.3.2
   
   # Install system dependencies
   RUN apt-get update && apt-get install -y \
       libssl-dev \
       libcurl4-openssl-dev \
       libxml2-dev
   
   # Install R packages
   RUN R -e "install.packages(c('shiny', 'bslib', 'plotly', 'DT', 'shinyWidgets', 'jsonlite', 'RColorBrewer'), repos='https://cran.rstudio.com/')"
   
   # Copy app
   COPY . /srv/shiny-server/cost-estimator
   COPY ../R /srv/R
   
   # Expose port
   EXPOSE 3838
   
   # Run
   CMD ["/usr/bin/shiny-server"]
   ```

2. **Build Image**
   ```bash
   docker build -t shiny-cost-estimator .
   ```

3. **Run Container**
   ```bash
   docker run -d -p 3838:3838 --name cost-estimator shiny-cost-estimator
   ```

4. **Access**: `http://localhost:3838/cost-estimator`

---

## 🔧 Pre-Deployment Checklist

### 1. Test Locally
```r
# Run from project root
shiny::runApp('cost-estimator-app')

# Test all three modes:
# - Local folder analysis
# - ZIP upload
# - Manual entry
```

### 2. Check Dependencies
```r
source('cost-estimator-app/check_dependencies.R')
```

### 3. Optimize for Deployment

**For shinyapps.io Free Tier:**

Edit `app.R` to reduce memory usage:

```r
# At top of app.R
options(shiny.maxRequestSize = 50*1024^2)  # already set in app.R (v2.0.0)

# Disable local folder browser for deployed version
if (Sys.getenv("R_CONFIG_ACTIVE") == "shinyapps") {
  # Hide local folder tab or show warning
}
```

**Add .Rprofile**:
```r
# cost-estimator-app/.Rprofile
if (file.exists("~/.Rprofile")) {
  source("~/.Rprofile")
}

options(
  repos = c(CRAN = "https://cran.rstudio.com/"),
  shiny.maxRequestSize = 50*1024^2
)
```

### 4. Configure Logging

Add to `app.R`:

```r
# Enable logging
options(shiny.trace = FALSE)
options(shiny.error = function() {
  logging::logerror(traceback())
})
```

---

## 🚨 Common Deployment Issues

### Issue 1: "Package not found"
**Solution:**
```r
# Install all dependencies before deploying
install.packages(c(
  "shiny", "bslib", "plotly", "DT", 
  "shinyWidgets", "jsonlite", "RColorBrewer"
))
```

### Issue 2: "Cannot find R files"
**Solution:** Ensure proper relative paths in `app.R`:
```r
# Use relative paths from app directory
source("../R/shiny_cost_estimator.R", local = TRUE)
source("../R/repo_code_analyzer.R", local = TRUE)
```

### Issue 3: "App disconnects immediately"
**Solution:** Check logs on shinyapps.io:
```r
rsconnect::showLogs(appName = "shiny-cost-estimator")
```

### Issue 4: "Folder browser not working"
**Expected:** Local folder browser doesn't work on remote servers.
**Solution:** Use ZIP upload mode for deployed version.

---

## 📊 Monitoring & Maintenance

### shinyapps.io Monitoring

```r
# Check app status
rsconnect::showMetrics(appName = "shiny-cost-estimator")

# View logs
rsconnect::showLogs(appName = "shiny-cost-estimator", entries = 100)

# Restart app
rsconnect::restartApp(appName = "shiny-cost-estimator")
```

### Usage Analytics

Enable in shinyapps.io dashboard:
- Active connections graph
- Memory usage
- CPU usage
- Active hours tracking

### Performance Tips

1. **Caching**: Cache expensive computations
   ```r
   analysis_cache <- memoise::memoise(analyze_repo_code)
   ```

2. **Async Processing**: For large repos
   ```r
   library(promises)
   library(future)
   plan(multisession)
   ```

3. **Progress Indicators**: For long operations
   ```r
   withProgress(message = 'Analyzing...', {
     # Long operation
   })
   ```

---

## 🔐 Security Best Practices

### 1. Input Validation
```r
# Validate file uploads
validate(
  need(input$zip_file, "Please select a file"),
  need(grepl("\\.zip$", input$zip_file$name), "Must be a ZIP file")
)
```

### 2. Sanitize Paths
```r
# Prevent directory traversal
safe_path <- normalizePath(input$local_path, mustWork = FALSE)
validate(need(file.exists(safe_path), "Invalid path"))
```

### 3. Rate Limiting
```r
# Limit analysis frequency
shiny::observeEvent(input$analyze_local, {
  req(throttle_check(session$token))
  # ... analysis code
})
```

### 4. Authentication (RStudio Connect)
```r
# Enable auth in manifest.json
{
  "requireAuth": true,
  "accessType": "acl"
}
```

---

## 🎯 Post-Deployment Testing

### Checklist:

- [ ] Home page loads correctly
- [ ] All tabs are accessible
- [ ] ZIP upload works (test with small repo)
- [ ] Manual entry calculates correctly
- [ ] Charts render properly
- [ ] Export functions work
- [ ] Shareable URLs generate
- [ ] Mobile responsive (test on phone)
- [ ] Error messages display clearly
- [ ] Help/documentation accessible

### Test Repositories:

Small (~5MB):
- https://github.com/rstudio/shiny-examples

Medium (~20MB):
- Your own projects

Large (>50MB):
- Test with warning message

---

## 📞 Support

**Deployment Help:**
- shinyapps.io support: support@rstudio.com
- Community forum: https://community.rstudio.com/
- Stack Overflow: `[shiny]` tag

**App Issues:**
- GitHub Issues: https://github.com/roldanalex/shiny-app-valuation/issues

---

**Ready to Deploy?** Follow Option 1 (shinyapps.io) for quickest setup!
