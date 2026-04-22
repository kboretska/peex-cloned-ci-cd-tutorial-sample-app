# Terraform — Azure VM Scale Set + Autoscale

Реалізація завдання з **автомасштабування VM** у **Azure**:

| Вимога | Ресурс |
|--------|--------|
| Launch template / образ | `azurerm_linux_virtual_machine_scale_set` (`source_image_reference`, `sku`, диски) |
| Група з min/max | VMSS `instances` + **autoscale** `capacity { minimum / maximum / default }` |
| ≥2 динамічні політики | Два **`rule`** у профілі `default` (CPU ↑ і CPU ↓) |
| Метрики | **Percentage CPU** (Average, PT5M / PT10M window) |
| Заплановане масштабування | Два профілі з **`recurrence`**: підвищений capacity будні **10:00–12:00** за часом **Києва** (`scheduled_timezone` = **`FLE Standard Time`** — Windows-ім’я, не IANA), далі базовий capacity з **12:00** |
| Cooldown | `scale_action.cooldown = PT5M` |
| Здоров’я | У VMSS базові перевірки платформи; для прод додайте LB + probe |

## Типи політик (Azure vs AWS)

- У **Azure** немає окремих термінів Simple/Step/Target як у AWS; у **Monitor autoscale** задаються **`rule`** з **`metric_trigger`** + **`scale_action`** (`ChangeCount`, `Increase`/`Decrease`).
- **Target-tracking-подібну** поведінку дають окремі налаштування або кілька порогів — у лабораторній роботі достатньо двох правил за CPU.

## Передумови

1. Встановити [Terraform](https://developer.hashicorp.com/terraform/install) та [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
2. Логін: `az login`
3. Дізнатися subscription id: `az account show --query id -o tsv`

## Змінні

Створіть `terraform.tfvars`:

```hcl
subscription_id       = "<guid>"
admin_ssh_public_key  = "ssh-ed25519 AAAA...your-public-key..."
# optional (defaults: northeurope + Standard_D2s_v3):
# location             = "swedencentral"
# vm_size              = "Standard_B2s"
```

## Команди

```bash
cd terraform-azure
terraform init
terraform plan
terraform apply
```

## Як перевірити scale-out / scale-in

1. Портал: **Virtual machine scale sets** → ваш VMSS → **Instances** — бачити кількість інстансів.
2. **Monitoring → Insights** або **Metrics** → CPU для VMSS.
3. Навантажити CPU без SSH (**Run Command** на одному інстансі VMSS):

```bash
RG="$(terraform output -raw resource_group_name)"
VMSS="$(terraform output -raw vmss_name)"
IID="$(az vmss list-instances -g "$RG" --name "$VMSS" --query '[0].instanceId' -o tsv)"

az vmss run-command invoke \
  -g "$RG" --name "$VMSS" --instance-id "$IID" \
  --command-id RunShellScript \
  --scripts "command -v stress-ng >/dev/null || (apt-get update -y && apt-get install -y stress-ng); stress-ng --cpu \$(nproc) --timeout 420"
```

Якщо налаштовано SSH до інстансів (LB/NAT/Bastion):

```bash
stress-ng --cpu $(nproc) --timeout 600
```

Спостерігайте **Monitor → autoscale** і **Activity log**.

## Знищення ресурсів

```bash
terraform destroy
```

## Помилка `SkuNotAvailable` / `409 Conflict` ( capacity )

Регіони інколи не видають обраний SKU — спробуйте інший **`vm_size`** або **`location`**. Докладніше: [aka.ms/azureskunotavailable](https://aka.ms/azureskunotavailable).

За замовчуванням у шаблоні **`Standard_D2s_v3`**; при **`SkuNotAvailable`** спробуйте інший **`vm_size`** або **`location`** (напр. `swedencentral`).

Якщо ресурсну групу вже створено в іншому регіоні, зміна `location` змушує Terraform **пересоздати** RG — часто `terraform destroy` потім `apply`.

Після зміни `location` / `vm_size`: `terraform apply` знову.

### Помилка autoscale «exceeding approved Total Regional Cores quota»

Це **квота vCPU по регіону**. Наприклад, **три** інстанси **D2s_v3** (по 2 vCPU) потребують **6** regional cores — при ліміті **4** scale-out до 3 інстансів може **падати**. Варіанти: **запит на збільшення квоти**, зменшити **`schedule_capacity_default`** / **`vmss_capacity_max`**, або менший **`vm_size`**.

## Вартість

- **D2s_v3** дорожчий за B/F малих SKU; для лаби з обмеженою квотою cores інколи зручніші **1 vCPU** SKU (з іншим ризиком `SkuNotAvailable`).
- Немає NAT Gateway у цьому мінімальному шаблоні — менше місячних фіксів.

## Артефакти для здачі

Скріншоти: VMSS (min/max), Autoscale setting (обидва профілі і правила), Metrics під час stress, Activity log при зміні instance count.
