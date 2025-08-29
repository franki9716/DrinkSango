#!/bin/bash

# Script de verificación rápida para toptraining.es
# Verifica que todo esté funcionando correctamente

DOMAIN="toptraining.es"
API_URL="https://$DOMAIN/api"

echo "🍹 Verificación SanguApp - $DOMAIN"
echo "=================================="

# Test 1: Ping básico
echo -n "🌐 DNS Resolution: "
if ping -c 1 $DOMAIN &> /dev/null; then
    echo "✅ OK"
else
    echo "❌ FAIL"
fi

# Test 2: HTTP Status
echo -n "🔗 HTTPS Status: "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN)
if [ "$STATUS" = "200" ]; then
    echo "✅ $STATUS"
else
    echo "❌ $STATUS"
fi

# Test 3: API Health
echo -n "🔧 API Health: "
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $API_URL/health)
if [ "$API_STATUS" = "200" ]; then
    echo "✅ $API_STATUS"
else
    echo "❌ $API_STATUS"
fi

# Test 4: SSL Certificate
echo -n "🔐 SSL Certificate: "
SSL_EXPIRY=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)
if [ ! -z "$SSL_EXPIRY" ]; then
    echo "✅ Valid until $SSL_EXPIRY"
else
    echo "❌ Invalid"
fi

# Test 5: Database Connection (si tenemos acceso)
if docker ps | grep -q "sanguapp_db_toptraining"; then
    echo -n "🗄️ Database: "
    if docker exec sanguapp_db_toptraining pg_isready -U sanguapp_prod &> /dev/null; then
        echo "✅ Connected"
    else
        echo "❌ Connection failed"
    fi
fi

# Test 6: Containers Status
echo -n "🐳 Docker Status: "
if docker ps | grep -q "sanguapp.*Up"; then
    RUNNING=$(docker ps | grep "sanguapp.*Up" | wc -l)
    echo "✅ $RUNNING containers running"
else
    echo "❌ No containers running"
fi

echo ""
echo "📊 Quick Stats:"
echo "   📁 Disk usage: $(df -h / | awk 'NR==2{print $5}')"
echo "   🧠 Memory usage: $(free | awk 'NR==2{printf "%.0f%%", $3*100/$2}')"
echo "   ⚡ Load average: $(uptime | awk -F'load average:' '{print $2}')"

echo ""
echo "🔗 Access URLs:"
echo "   🌐 Main App: https://$DOMAIN"
echo "   📊 Admin Panel: https://$DOMAIN/admin"
echo "   🔧 API Health: $API_URL/health"

echo ""
echo "✅ Verification complete!"
