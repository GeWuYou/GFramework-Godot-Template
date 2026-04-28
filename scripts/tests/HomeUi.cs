using GFrameworkGodotTemplate.scripts.core.ui;
using GFrameworkGodotTemplate.scripts.enums.scene;
using GFrameworkGodotTemplate.scripts.enums.ui;
using Godot;

namespace GFrameworkGodotTemplate.scripts.tests;

[ContextAware]
[Log]
public partial class HomeUi : Control, IController, IUiPageBehaviorProvider, ISimpleUiPage
{
    [GetNode] private Button _homeButton = null!;

    /// <summary>
    ///     页面行为实例的私有字段
    /// </summary>
    private IUiPageBehavior? _page;

    [GetNode] private Button _scene1Button = null!;
    [GetNode] private Button _scene2Button = null!;

    private bool _isSwitchingScene;

    private ISceneRouter _sceneRouter = null!;

    /// <summary>
    ///     Ui Key的字符串形式
    /// </summary>
    public static string UiKeyStr => nameof(UiKey.HomeUi);

    /// <summary>
    ///     获取页面行为实例，如果不存在则创建新的CanvasItemUiPageBehavior实例
    /// </summary>
    /// <returns>返回IUiPageBehavior类型的页面行为实例</returns>
    public IUiPageBehavior GetPage()
    {
        _page ??= UiPageBehaviorFactory.Create<Control>(this, UiKeyStr, UiLayer.Page);
        return _page;
    }

    /// <summary>
    ///     检查当前UI是否在路由栈顶，如果不在则将页面推入路由栈
    /// </summary>
    private void CallDeferredInit()
    {
        // 在此添加延迟初始化逻辑
    }

    /// <summary>
    ///     节点准备就绪时的回调方法
    ///     在节点添加到场景树后调用
    /// </summary>
    public override void _Ready()
    {
        __InjectGetNodes_Generated();
        Hide();
        _sceneRouter = this.GetSystem<ISceneRouter>()!;

        // 在此添加就绪逻辑
        SetupEventHandlers();
        // 这个需要延迟调用，因为UiRoot还没有添加到场景树中
        CallDeferred(nameof(CallDeferredInit));
        Show();
    }

    /// <summary>
    ///     设置事件处理器
    /// </summary>
    private void SetupEventHandlers()
    {
        var buttons = new[] { _scene1Button, _scene2Button, _homeButton };

        _scene1Button.Pressed += async () => await SwitchSceneAsync(nameof(SceneKey.Scene1)).ConfigureAwait(true);
        _scene2Button.Pressed += async () => await SwitchSceneAsync(nameof(SceneKey.Scene2)).ConfigureAwait(true);
        _homeButton.Pressed += async () => await SwitchSceneAsync(nameof(SceneKey.Home)).ConfigureAwait(true);
        return;

        async Task SwitchSceneAsync(string sceneKey)
        {
            if (_isSwitchingScene) return;

            // 检查是否是当前场景
            if (string.Equals(_sceneRouter.CurrentKey, sceneKey, StringComparison.Ordinal))
            {
                _log.Debug($"已在场景 {sceneKey}，忽略切换请求");
                return;
            }

            _isSwitchingScene = true;

            // 禁用所有按钮，防止重复点击
            SetSceneButtonsDisabled(buttons, true);

            try
            {
                await _sceneRouter.ReplaceAsync(sceneKey).AsTask().ConfigureAwait(true);
            }
            catch (Exception ex)
            {
                _log.Error($"场景切换失败: {ex.Message}");
            }
            finally
            {
                _isSwitchingScene = false;

                // 重新启用所有按钮
                SetSceneButtonsDisabled(buttons, false);
            }
        }
    }

    /// <summary>
    ///     安全切换场景按钮状态。场景切换可能销毁当前 HomeUi，异步收尾时不能再访问失效的 Godot 对象。
    /// </summary>
    /// <param name="buttons">需要更新的按钮集合。</param>
    /// <param name="disabled">是否禁用按钮。</param>
    private void SetSceneButtonsDisabled(IEnumerable<Button> buttons, bool disabled)
    {
        if (!GodotObject.IsInstanceValid(this) || IsQueuedForDeletion() || !IsInsideTree()) return;

        foreach (var button in buttons)
        {
            if (!GodotObject.IsInstanceValid(button) || button.IsQueuedForDeletion()) continue;

            button.Disabled = disabled;
        }
    }
}
