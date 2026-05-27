using GFrameworkGodotTemplate.scripts.config;
using GFrameworkGodotTemplate.scripts.core.state.impls;
using GFrameworkGodotTemplate.scripts.core.ui;
using GFrameworkGodotTemplate.scripts.cqrs.game.command;
using GFrameworkGodotTemplate.scripts.cqrs.menu.command;
using GFrameworkGodotTemplate.scripts.cqrs.pause_menu.command.input;
using GFrameworkGodotTemplate.scripts.enums.ui;
using Godot;

namespace GFrameworkGodotTemplate.scripts.pause_menu;

[ContextAware]
[Log]
public partial class PauseMenu : Control, IController, IUiPageBehaviorProvider, ISimpleUiPage,
    IUiInteractionProfileProvider, IUiActionHandler
{
    private bool _isTransitionInProgress;

    [GetUtility] private ITemplateContentCatalog _contentCatalog = null!;

    /// <summary>
    ///     获取加载游戏按钮节点
    /// </summary>
    [GetNode] private Button _loadButton = null!;

    private ILocalizationManager? _localizationManager;

    /// <summary>
    ///     获取主菜单按钮节点
    /// </summary>
    [GetNode] private Button _mainMenuButton = null!;

    /// <summary>
    ///     获取选项按钮节点
    /// </summary>
    [GetNode] private Button _optionsButton = null!;

    /// <summary>
    ///     页面行为实例的私有字段
    /// </summary>
    private IUiPageBehavior? _page;

    /// <summary>
    ///     获取退出游戏按钮节点
    /// </summary>
    [GetNode] private Button _quitButton = null!;

    /// <summary>
    ///     获取恢复游戏按钮节点
    /// </summary>
    [GetNode] private Button _resumeButton = null!;

    /// <summary>
    ///     获取保存游戏按钮节点
    /// </summary>
    [GetNode] private Button _saveButton = null!;

    private IStateMachineSystem _stateMachineSystem = null!;

    [GetNode("Panel/MarginContainer/HBoxContainer/MarginContainer/HBoxContainer/Title")]
    private Label _titleLabel = null!;

    /// <summary>
    ///     Ui Key的字符串形式
    /// </summary>
    public static string UiKeyStr => nameof(UiKey.PauseMenu);

    /// <summary>
    ///     处理由路由器仲裁后的取消动作。
    /// </summary>
    bool IUiActionHandler.TryHandleUiAction(UiInputAction action)
    {
        if (action != UiInputAction.Cancel || !Visible) return false;

        if (_isTransitionInProgress) return true;

        RunUiTransition(ResumeGameAndClosePauseMenuAsync);
        return true;
    }

    /// <summary>
    ///     声明暂停菜单在可见时阻断玩法输入并持有全局暂停。
    /// </summary>
    UiInteractionProfile IUiInteractionProfileProvider.GetUiInteractionProfile(UiLayer layer)
    {
        return new UiInteractionProfile
        {
            CapturedActions = UiInputActionMask.Cancel,
            BlocksWorldPointerInput = true,
            BlocksWorldActionInput = true,
            PauseMode = UiPauseMode.WhileVisible,
            ContinueProcessingWhenPaused = true,
            PauseReason = "PauseMenu"
        };
    }


    public IUiPageBehavior GetPage()
    {
        _page ??= UiPageBehaviorFactory.Create<Control>(this, UiKeyStr, UiLayer.Modal);
        return _page;
    }

    /// <summary>
    ///     节点就绪时调用的方法，用于初始化UI和设置事件处理器
    /// </summary>
    public override void _Ready()
    {
        __InjectGetNodes_Generated();
        __InjectContextBindings_Generated();
        SetupEventHandlers();
        ConfigureUnavailableActions();
        _stateMachineSystem = this.GetSystem<IStateMachineSystem>()!;
        _localizationManager = this.GetSystem<ILocalizationManager>()!;
        _localizationManager.SubscribeToLanguageChange(OnLanguageChanged);
        this.RegisterEvent<SettingsAppliedEvent<ISettingsSection>>(OnSettingsApplied);
        ApplyStaticText();
    }

    public override void _ExitTree()
    {
        this.UnRegisterEvent<SettingsAppliedEvent<ISettingsSection>>(OnSettingsApplied);
        _localizationManager?.UnsubscribeFromLanguageChange(OnLanguageChanged);
    }

    /// <summary>
    ///     设置按钮点击事件处理器
    ///     为各个按钮绑定相应的命令发送逻辑
    /// </summary>
    private void SetupEventHandlers()
    {
        // 绑定恢复游戏按钮点击事件
        _resumeButton.Pressed += () =>
        {
            if (_isTransitionInProgress) return;

            RunUiTransition(ResumeGameAndClosePauseMenuAsync);
        };
        // 绑定加载游戏按钮点击事件
        _loadButton.Pressed += () => { _log.Debug("加载游戏"); };
        // 绑定选项按钮点击事件
        _optionsButton.Pressed += () => { this.RunCommandCoroutine(new OpenOptionsMenuCommand()); };

        // 绑定返回主菜单按钮点击事件
        _mainMenuButton.Pressed += () =>
        {
            if (_isTransitionInProgress) return;

            RunUiTransition(ReturnToMainMenuAsync);
        };

        // 绑定退出游戏按钮点击事件
        _quitButton.Pressed += () => this.RunCommandCoroutine(new ExitGameCommand());
    }

    private async Task ReturnToMainMenuAsync()
    {
        await ResumeGameAndClosePauseMenuAsync().ConfigureAwait(true);
        await _stateMachineSystem.ChangeToAsync<MainMenuState>().ConfigureAwait(true);
    }

    private void RunUiTransition(Func<Task> transition)
    {
        _isTransitionInProgress = true;
        RunUiTransitionCoreAsync(transition).ToCoroutineEnumerator().RunCoroutine(Segment.ProcessIgnorePause);
    }

    private async Task RunUiTransitionCoreAsync(Func<Task> transition)
    {
        try
        {
            await transition().ConfigureAwait(true);
        }
        finally
        {
            _isTransitionInProgress = false;
        }
    }

    private async Task ResumeGameAndClosePauseMenuAsync()
    {
        var handle = GetPage().Handle;
        if (handle is null) return;

        await this.SendAsync(new ResumeGameWithClosePauseMenuCommand(new ClosePauseMenuCommandInput
        {
            Handle = handle.Value
        })).ConfigureAwait(true);
    }

    private void ConfigureUnavailableActions()
    {
        _saveButton.Disabled = true;
    }

    private void ApplyStaticText()
    {
        var text = _contentCatalog.GetMenuText();
        _titleLabel.Text = text.PauseTitle;
        _resumeButton.Text = text.PauseResume;
        _saveButton.Text = text.PauseSave;
        _loadButton.Text = text.PauseLoad;
        _optionsButton.Text = text.PauseOptions;
        _mainMenuButton.Text = text.PauseMainMenu;
        _quitButton.Text = text.PauseQuit;
    }

    private void OnLanguageChanged(string _)
    {
        ApplyStaticText();
    }

    private void OnSettingsApplied(SettingsAppliedEvent<ISettingsSection> @event)
    {
        if (!@event.Success ||
            @event.Settings is not IResetApplyAbleSettings settings ||
            settings.DataType != typeof(LocalizationSettings))
            return;

        ApplyStaticText();
    }
}
